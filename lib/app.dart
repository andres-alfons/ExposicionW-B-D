import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/connectivity_service.dart';
import 'services/bluetooth_service.dart';
import 'services/permission_service.dart';
import 'screens/bluetooth_screen.dart';
import 'screens/permissions_screen.dart';
import 'screens/chat_screen.dart';
import 'services/chat_service.dart';
import 'services/image_service.dart';
import 'services/users_service.dart';
import 'screens/users_screen.dart';

class ConectaLabApp extends StatelessWidget {
  const ConectaLabApp({
    super.key,
    this.connectivityService,
    this.permissionService,
    this.bluetoothService,
    this.chatService,
  });
  final ConnectivityService? connectivityService;
  final PermissionService? permissionService;
  final BluetoothService? bluetoothService;
  final ChatService? chatService;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ConectaLab',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF38D9F5),
        brightness: Brightness.dark,
        surface: const Color(0xFF11243A),
      ),
      scaffoldBackgroundColor: const Color(0xFF071322),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF24415A)),
        ),
      ),
    ),
    home: LabShell(
      connectivityService: connectivityService,
      permissionService: permissionService,
      bluetoothService: bluetoothService,
      chatService: chatService,
    ),
  );
}

class LabShell extends StatefulWidget {
  const LabShell({
    super.key,
    this.connectivityService,
    this.permissionService,
    this.bluetoothService,
    this.chatService,
  });
  final ConnectivityService? connectivityService;
  final PermissionService? permissionService;
  final BluetoothService? bluetoothService;
  final ChatService? chatService;
  @override
  State<LabShell> createState() => _LabShellState();
}

class _LabShellState extends State<LabShell> with WidgetsBindingObserver {
  late final ConnectivityService connectivity;
  late final PermissionService permissions;
  late final BluetoothService bluetooth;
  late final ChatService chat;
  late final UsersService users;

  @override
  void initState() {
    super.initState();
    connectivity = widget.connectivityService ?? ConnectivityService();
    permissions =
        widget.permissionService ??
        widget.bluetoothService?.permissions ??
        PermissionService();
    bluetooth =
        widget.bluetoothService ?? BluetoothService(permissions: permissions);
    chat =
        widget.chatService ??
        ChatService(images: ImageService(permissions: permissions));
    WidgetsBinding.instance.addObserver(this);
    users = UsersService();
    connectivity.start();
    // Android puede devolver una selección tras recrear la actividad. Solo se
    // recupera como vista previa; nunca se añade un mensaje sin confirmación.
    chat.recoverImage();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android no garantiza eventos mientras la app está en segundo plano.
    if (state == AppLifecycleState.resumed) {
      connectivity.refresh();
      permissions.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.connectivityService == null) connectivity.dispose();
    if (widget.bluetoothService == null) bluetooth.dispose();
    if (widget.chatService == null) chat.dispose();
    users.dispose();
    if (widget.permissionService == null && widget.bluetoothService == null) {
      permissions.dispose();
    }
    super.dispose();
  }

  int selected = 0;
  static const labels = ['Inicio', 'Chat', 'Usuarios', 'Bluetooth', 'Permisos'];
  static const icons = [
    Icons.dashboard_outlined,
    Icons.chat_bubble_outline,
    Icons.people_outline,
    Icons.bluetooth,
    Icons.shield_outlined,
  ];
  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(
        service: connectivity,
        onBluetooth: () => setState(() => selected = 3),
      ),
      ChatScreen(chat: chat, connectivity: connectivity),
      UsersScreen(
        users: users,
        connectivity: connectivity,
        onPermissions: () => setState(() => selected = 4),
      ),
      BluetoothScreen(service: bluetooth),
      PermissionsScreen(service: permissions),
    ];
    // Una sola selección controla las dos variantes de navegación.
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                if (wide) ...[
                  NavigationRail(
                    extended: constraints.maxWidth >= 1100,
                    selectedIndex: selected,
                    onDestinationSelected: (i) => setState(() => selected = i),
                    leading: const Padding(
                      padding: EdgeInsets.all(24),
                      child: Icon(Icons.hub_outlined, size: 32),
                    ),
                    destinations: List.generate(
                      labels.length,
                      (i) => NavigationRailDestination(
                        icon: Icon(icons[i]),
                        label: Text(labels[i]),
                      ),
                    ),
                  ),
                  const VerticalDivider(width: 1),
                ],
                Expanded(child: pages[selected]),
              ],
            ),
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selected,
                  onDestinationSelected: (i) => setState(() => selected = i),
                  destinations: List.generate(
                    labels.length,
                    (i) => NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                  ),
                ),
        );
      },
    );
  }
}
