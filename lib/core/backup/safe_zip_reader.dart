import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' show getCrc32;

import 'backup_manifest.dart';

class BackupLimits {
  const BackupLimits({
    this.maxArchiveBytes = 50 * 1024 * 1024,
    this.maxEntryBytes = 100 * 1024 * 1024,
    this.maxTotalUncompressedBytes = 100 * 1024 * 1024,
    this.maxCompressionRatio = 1000,
    this.maxRowsPerTable = 100000,
    this.maxJsonDepth = 32,
    this.maxJsonTokens = 1000000,
  });

  final int maxArchiveBytes;
  final int maxEntryBytes;
  final int maxTotalUncompressedBytes;
  final int maxCompressionRatio;
  final int maxRowsPerTable;
  final int maxJsonDepth;
  final int maxJsonTokens;
}

class SafeZipReader {
  const SafeZipReader(this.limits);

  final BackupLimits limits;

  Future<Map<String, Uint8List>> read(File file) async {
    final handle = await file.open();
    try {
      final initialLength = await handle.length();
      if (initialLength > limits.maxArchiveBytes) {
        throw const BackupIntegrityException('Archive too large');
      }
      final builder = BytesBuilder(copy: false);
      var total = 0;
      while (true) {
        final remaining = limits.maxArchiveBytes + 1 - total;
        if (remaining <= 0) {
          throw const BackupIntegrityException('Archive too large');
        }
        final chunk = await handle.read(
          remaining < 64 * 1024 ? remaining : 64 * 1024,
        );
        if (chunk.isEmpty) break;
        total += chunk.length;
        builder.add(chunk);
      }
      final finalLength = await handle.length();
      if (total != initialLength || finalLength != initialLength) {
        throw const BackupIntegrityException('Archive changed while reading');
      }
      return readBytes(builder.takeBytes());
    } finally {
      await handle.close();
    }
  }

  Map<String, Uint8List> readBytes(List<int> source) {
    final bytes = source is Uint8List ? source : Uint8List.fromList(source);
    if (bytes.length > limits.maxArchiveBytes) {
      throw const BackupIntegrityException('Archive too large');
    }
    final entries = _readDirectory(bytes);
    var actualTotal = 0;
    final result = <String, Uint8List>{};
    for (final entry in entries) {
      final remaining = limits.maxTotalUncompressedBytes - actualTotal;
      final outputLimit = entry.uncompressedSize < remaining
          ? entry.uncompressedSize
          : remaining;
      final content = _inflate(bytes, entry, outputLimit);
      actualTotal += content.length;
      if (actualTotal > limits.maxTotalUncompressedBytes) {
        throw const BackupIntegrityException(
          'Archive expansion limit exceeded',
        );
      }
      if (content.length != entry.uncompressedSize ||
          getCrc32(content) != entry.crc32) {
        throw const BackupIntegrityException('ZIP entry integrity mismatch');
      }
      result[entry.name] = content;
    }
    return result;
  }

  List<_ZipEntry> _readDirectory(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final eocd = _findEocd(data);
    if (_u16(data, eocd + 4) != 0 ||
        _u16(data, eocd + 6) != 0 ||
        _u16(data, eocd + 8) != 2 ||
        _u16(data, eocd + 10) != 2) {
      throw const BackupIntegrityException('Unsupported ZIP directory');
    }
    final directorySize = _u32(data, eocd + 12);
    final directoryOffset = _u32(data, eocd + 16);
    if (directoryOffset + directorySize != eocd ||
        directoryOffset < 0 ||
        directoryOffset + directorySize > bytes.length) {
      throw const BackupIntegrityException('Invalid ZIP directory bounds');
    }
    var cursor = directoryOffset;
    var declaredTotal = 0;
    final entries = <_ZipEntry>[];
    final names = <String>{};
    while (cursor < eocd) {
      if (cursor + 46 > eocd || _u32(data, cursor) != 0x02014b50) {
        throw const BackupIntegrityException('Invalid ZIP directory entry');
      }
      final flags = _u16(data, cursor + 8);
      final method = _u16(data, cursor + 10);
      final crc32 = _u32(data, cursor + 16);
      final compressedSize = _u32(data, cursor + 20);
      final uncompressedSize = _u32(data, cursor + 24);
      final nameLength = _u16(data, cursor + 28);
      final extraLength = _u16(data, cursor + 30);
      final commentLength = _u16(data, cursor + 32);
      final diskStart = _u16(data, cursor + 34);
      final externalAttributes = _u32(data, cursor + 38);
      final localOffset = _u32(data, cursor + 42);
      final end = cursor + 46 + nameLength + extraLength + commentLength;
      if (end > eocd ||
          diskStart != 0 ||
          (flags & (1 | 8)) != 0 ||
          (flags & ~0x800) != 0) {
        throw const BackupIntegrityException('Unsupported ZIP entry');
      }
      final nameBytes = bytes.sublist(cursor + 46, cursor + 46 + nameLength);
      final name = utf8.decode(nameBytes, allowMalformed: false);
      if (!_allowedName(name) ||
          !names.add(name) ||
          (method != 0 && method != 8)) {
        throw const BackupIntegrityException('Unexpected ZIP entry');
      }
      final mode = externalAttributes >> 16;
      final fileType = mode & 0xf000;
      if (fileType != 0 && fileType != 0x8000) {
        throw const BackupIntegrityException('Non-regular ZIP entry');
      }
      if (compressedSize > limits.maxArchiveBytes ||
          uncompressedSize > limits.maxEntryBytes ||
          (compressedSize == 0 && uncompressedSize != 0) ||
          (compressedSize > 0 &&
              uncompressedSize > compressedSize * limits.maxCompressionRatio)) {
        throw const BackupIntegrityException(
          'ZIP entry expansion limit exceeded',
        );
      }
      declaredTotal += uncompressedSize;
      if (declaredTotal > limits.maxTotalUncompressedBytes) {
        throw const BackupIntegrityException(
          'Archive expansion limit exceeded',
        );
      }
      final entry = _ZipEntry(
        name: name,
        nameBytes: nameBytes,
        flags: flags,
        method: method,
        crc32: crc32,
        compressedSize: compressedSize,
        uncompressedSize: uncompressedSize,
        localOffset: localOffset,
      );
      _validateLocalHeader(data, bytes, entry, directoryOffset);
      entries.add(entry);
      cursor = end;
    }
    if (entries.length != 2 ||
        !names.contains('manifest.json') ||
        !names.contains('data.json')) {
      throw const BackupIntegrityException('Unexpected ZIP entries');
    }
    final byOffset = entries.toList()
      ..sort((a, b) => a.localOffset.compareTo(b.localOffset));
    if (byOffset.first.dataOffset + byOffset.first.compressedSize >
        byOffset.last.localOffset) {
      throw const BackupIntegrityException('Overlapping ZIP entries');
    }
    return entries;
  }

  void _validateLocalHeader(
    ByteData data,
    Uint8List bytes,
    _ZipEntry entry,
    int directoryOffset,
  ) {
    final offset = entry.localOffset;
    if (offset + 30 > directoryOffset || _u32(data, offset) != 0x04034b50) {
      throw const BackupIntegrityException('Invalid ZIP local header');
    }
    final nameLength = _u16(data, offset + 26);
    final extraLength = _u16(data, offset + 28);
    final dataOffset = offset + 30 + nameLength + extraLength;
    if (_u16(data, offset + 6) != entry.flags ||
        _u16(data, offset + 8) != entry.method ||
        ((entry.flags & 8) == 0 &&
            (_u32(data, offset + 14) != entry.crc32 ||
                _u32(data, offset + 18) != entry.compressedSize ||
                _u32(data, offset + 22) != entry.uncompressedSize)) ||
        dataOffset + entry.compressedSize > directoryOffset ||
        nameLength != entry.nameBytes.length ||
        !_equalBytes(
          bytes.sublist(offset + 30, offset + 30 + nameLength),
          entry.nameBytes,
        )) {
      throw const BackupIntegrityException('ZIP header mismatch');
    }
    entry.dataOffset = dataOffset;
  }

  Uint8List _inflate(Uint8List bytes, _ZipEntry entry, int outputLimit) {
    final compressed = bytes.sublist(
      entry.dataOffset,
      entry.dataOffset + entry.compressedSize,
    );
    if (entry.method == 0) {
      if (compressed.length > outputLimit) {
        throw const BackupIntegrityException('ZIP entry output too large');
      }
      return Uint8List.fromList(compressed);
    }
    final sink = _LimitedBytesSink(outputLimit);
    final decoder = ZLibDecoder(raw: true).startChunkedConversion(sink);
    const chunkSize = 16 * 1024;
    for (var offset = 0; offset < compressed.length; offset += chunkSize) {
      final end = offset + chunkSize < compressed.length
          ? offset + chunkSize
          : compressed.length;
      decoder.add(compressed.sublist(offset, end));
    }
    decoder.close();
    return sink.bytes;
  }

  int _findEocd(ByteData data) {
    final minimum = data.lengthInBytes > 65557 ? data.lengthInBytes - 65557 : 0;
    for (var offset = data.lengthInBytes - 22; offset >= minimum; offset--) {
      if (_u32(data, offset) == 0x06054b50 &&
          offset + 22 + _u16(data, offset + 20) == data.lengthInBytes) {
        return offset;
      }
    }
    throw const BackupIntegrityException('Missing ZIP directory');
  }

  bool _allowedName(String name) =>
      (name == 'manifest.json' || name == 'data.json') &&
      !name.startsWith('/') &&
      !name.replaceAll('\\', '/').split('/').contains('..');

  static int _u16(ByteData data, int offset) {
    if (offset < 0 || offset + 2 > data.lengthInBytes) {
      throw const BackupIntegrityException('Truncated ZIP data');
    }
    return data.getUint16(offset, Endian.little);
  }

  static int _u32(ByteData data, int offset) {
    if (offset < 0 || offset + 4 > data.lengthInBytes) {
      throw const BackupIntegrityException('Truncated ZIP data');
    }
    return data.getUint32(offset, Endian.little);
  }

  static bool _equalBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _ZipEntry {
  _ZipEntry({
    required this.name,
    required this.nameBytes,
    required this.flags,
    required this.method,
    required this.crc32,
    required this.compressedSize,
    required this.uncompressedSize,
    required this.localOffset,
  });

  final String name;
  final List<int> nameBytes;
  final int flags;
  final int method;
  final int crc32;
  final int compressedSize;
  final int uncompressedSize;
  final int localOffset;
  late final int dataOffset;
}

class _LimitedBytesSink implements Sink<List<int>> {
  _LimitedBytesSink(this.limit);

  final int limit;
  final BytesBuilder _builder = BytesBuilder(copy: false);
  var _length = 0;

  @override
  void add(List<int> data) {
    _length += data.length;
    if (_length > limit) {
      throw const BackupIntegrityException('ZIP entry output too large');
    }
    _builder.add(data);
  }

  @override
  void close() {}

  Uint8List get bytes => _builder.takeBytes();
}
