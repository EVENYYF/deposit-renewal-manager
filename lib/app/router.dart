import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/notification_scheduler.dart';
import '../features/customers/application/customer_controller.dart';
import '../features/customers/presentation/customer_pages.dart';
import '../features/dashboard/application/dashboard_controller.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/deposits/presentation/deposit_form_page.dart';
import '../features/excel_import/presentation/import_wizard.dart';
import '../features/settings/presentation/backup_settings_page.dart';
import '../features/statistics/presentation/deposit_statistics_page.dart';
import '../features/templates/presentation/templates_page.dart';
import '../features/text_import/presentation/text_import_page.dart';
import 'app_dependencies.dart';
import 'shell.dart';

abstract final class AppRouteNames {
  static const dashboard = 'dashboard';
  static const customers = 'customers';
  static const addDeposit = 'addDeposit';
  static const settings = 'settings';
  static const notification = 'notification';
}

final routerProvider = Provider<GoRouter>((ref) {
  final router = createAppRouter();
  ref.onDispose(router.dispose);
  return router;
});

GoRouter createAppRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) =>
          ResponsiveAppShell(navigationShell: shell),
      branches: [
        _branch(
          AppRouteNames.dashboard,
          '/',
          const DashboardPage(),
          routes: [
            GoRoute(
              name: AppRouteNames.notification,
              path: 'notifications/:notificationId',
              builder: (context, state) => _NotificationDepositPage(
                depositId: state.pathParameters['notificationId']!,
              ),
            ),
          ],
        ),
        _branch(
          AppRouteNames.customers,
          '/customers',
          const CustomerDirectoryPage(),
        ),
        _branch(
          AppRouteNames.addDeposit,
          '/deposits/new',
          const _NewEntryPage(),
        ),
        _branch(AppRouteNames.settings, '/settings', const _SettingsPage()),
      ],
    ),
  ],
);

StatefulShellBranch _branch(
  String name,
  String path,
  Widget child, {
  List<GoRoute> routes = const [],
}) => StatefulShellBranch(
  routes: [
    GoRoute(
      name: name,
      path: path,
      builder: (context, state) => child,
      routes: routes,
    ),
  ],
);

class _NotificationDepositPage extends StatelessWidget {
  const _NotificationDepositPage({required this.depositId});
  final String depositId;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('存款提醒')),
    body: Center(child: Text('通知\n$depositId', textAlign: TextAlign.center)),
  );
}

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text('设置', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      const NotificationStatusBanner(),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.settings_outlined),
        title: const Text('系统通知设置'),
        subtitle: const Text('检查通知与闹钟权限'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => ref
            .read(notificationCapabilityControllerProvider.notifier)
            .openSettings(),
      ),
      const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('系统限制'),
        subtitle: Text('应用被强行停止后 Android 不会恢复提醒；厂商省电策略也可能造成延迟。'),
      ),
    ],
  );
}

class _NewEntryPage extends ConsumerWidget {
  const _NewEntryPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('新增', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      ListTile(
        leading: const Icon(Icons.edit_note),
        title: const Text('手工新增存款'),
        subtitle: const Text('逐项填写客户编号和存款信息'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _push(context, const DepositFormPage()),
      ),
      ListTile(
        leading: const Icon(Icons.text_snippet_outlined),
        title: const Text('从大段文字识别'),
        subtitle: const Text('离线识别，核对确认后才保存'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _push(
          context,
          TextImportPage(
            onConfirmedSave: ref.read(confirmedTextImportProvider),
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.table_view_outlined),
        title: const Text('Excel 批量导入'),
        subtitle: const Text('支持 .xlsx 预览、查重和确认导入'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _push(
          context,
          ExcelImportWizard(bindings: ref.read(excelImportBindingsProvider)),
        ),
      ),
    ],
  );

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('设置', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      const NotificationStatusBanner(),
      ListTile(
        leading: const Icon(Icons.description_outlined),
        title: const Text('消息模板'),
        subtitle: const Text('管理续期提示语模板'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => TemplatesPage(
              bindings: ref.read(templateBindingsProvider),
            ),
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.query_stats),
        title: const Text('存款统计'),
        subtitle: const Text('查看当前本金、状态及银行产品汇总'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const DepositStatisticsPage(),
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.backup_outlined),
        title: const Text('备份、恢复与快照'),
        subtitle: const Text('导出本地文件或检查恢复影响'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BackupSettingsPage(
              backup: ref.read(backupServiceProvider),
              afterRestore: () async {
                ref.invalidate(customerControllerProvider);
                ref.invalidate(dashboardControllerProvider);
                await ref
                    .read(notificationMutationCoordinatorProvider)
                    .reconcileAll();
              },
            ),
          ),
        ),
      ),
      ListTile(
        leading: const Icon(Icons.settings_outlined),
        title: const Text('系统通知设置'),
        subtitle: const Text('检查通知与闹钟权限'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => ref
            .read(notificationCapabilityControllerProvider.notifier)
            .openSettings(),
      ),
      const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('系统限制'),
        subtitle: Text('应用被强行停止后 Android 不会恢复提醒；厂商省电策略也可能造成延迟。'),
      ),
    ],
  );
}
