import '../domain/text_deposit_parser.dart';

final class ParseDepositText {
  const ParseDepositText(this._parser);

  final TextDepositParser _parser;

  ParseResult call(String source) => _parser.parse(source);
}
