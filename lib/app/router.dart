import 'package:deposit_renewal_manager/features/dashboard/application/dashboard_controller.dart';
import 'package:deposit_renewal_manager/core/notifications/notification_scheduler.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
              builder: (context, state) => _PlaceholderPage(
                title: '通知',
                subtitle: state.pathParameters['notificationId'],
              ),
            ),
          ],
        ),
        _branch(
          AppRouteNames.customers,
          '/customers',
          const _PlaceholderPage(title: '客户'),
        ),
        _branch(
          AppRouteNames.addDeposit,
          '/deposits/new',
          const _PlaceholderPage(title: '新增存款'),
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

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(dashboardControllerProvider);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('存款续期', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          const NotificationStatusBanner(),
          const SizedBox(height: 24),
          Expanded(
            child: value.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _StateMessage(
                title: '暂时无法加载首页',
                actionLabel: '重试',
                onAction: () =>
                    ref.read(dashboardControllerProvider.notifier).retry(),
              ),
              data: (snapshot) => snapshot.isEmpty
                  ? const _StateMessage(title: '暂无续期数据')
                  : _DashboardSummary(snapshot: snapshot),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationStatusBanner extends ConsumerWidget {
  const NotificationStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationCapabilityControllerProvider);
    final capability = state.capability;
    final message = state.message;
    if (capability == null && message == null && !state.busy) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(
      notificationCapabilityControllerProvider.notifier,
    );
    final needsPermission = state.needsNotificationPermission;
    final needsExact =
        capability?.notificationsAllowed == true &&
        capability?.canScheduleExact == false;
    final label = needsPermission
        ? '开启通知'
        : needsExact
        ? '开启精确提醒'
        : '重试';
    final action = needsPermission
        ? controller.requestNotificationPermission
        : needsExact
        ? controller.requestExactAlarmPermission
        : controller.reconcileAll;
    return MaterialBanner(
      content: Text(message ?? (state.busy ? '正在更新通知状态…' : '通知提醒需要处理')),
      actions: [
        TextButton(onPressed: state.busy ? null : action, child: Text(label)),
      ],
    );
  }
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
        subtitle: const Text('可检查通知与闹钟权限'),
        trailing: const Icon(Icons.open_in_new),
        onTap: () => ref
            .read(notificationCapabilityControllerProvider.notifier)
            .openSettings(),
      ),
      const ListTile(
        leading: Icon(Icons.info_outline),
        title: Text('系统限制'),
        subtitle: Text('应用被强行停止后，Android 不会恢复提醒；请重新打开应用。'),
      ),
    ],
  );
}

class _DashboardSummary extends StatelessWidget {
  const _DashboardSummary({required this.snapshot});
  final DashboardSnapshot snapshot;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Text('即将到期：${snapshot.dueSoonCount}'),
      Text('已逾期：${snapshot.overdueCount}'),
      Text('客户数：${snapshot.customerCount}'),
    ],
  );
}

class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        subtitle == null ? title : '$title\n$subtitle',
        textAlign: TextAlign.center,
      ),
    ),
  );
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, textAlign: TextAlign.center),
        if (actionLabel != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}
