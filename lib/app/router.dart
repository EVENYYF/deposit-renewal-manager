import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/notifications/notification_scheduler.dart';
import '../features/customers/presentation/customer_pages.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/deposits/presentation/deposit_form_page.dart';
import 'shell.dart';

abstract final class AppRouteNames {
  static const dashboard = 'dashboard';
  static const customers = 'customers';
  static const addDeposit = 'addDeposit';
  static const templates = 'templates';
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
          const DepositFormPage(),
        ),
        _branch(
          AppRouteNames.templates,
          '/templates',
          const _PlaceholderPage(title: '模板'),
        ),
        _branch(
          AppRouteNames.settings,
          '/settings',
          const NotificationSettingsPage(),
        ),
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

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Center(child: Text(title));
}
