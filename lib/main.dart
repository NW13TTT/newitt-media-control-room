import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/routing/control_room_navigation.dart';
import 'app/routing/control_room_navigation_view.dart';
import 'app/routing/control_room_router.dart';
import 'auth/account_profile_screen.dart';
import 'auth/auth_controller.dart';
import 'auth/auth_gate.dart';
import 'auth/auth_models.dart';
import 'auth/auth_service.dart';
import 'help/smart_help_button.dart';
import 'backend/supabase/supabase_auth_service.dart';
import 'backend/supabase/supabase_config.dart';
import 'backend/supabase/supabase_control_room_repository.dart';
import 'backend/supabase/supabase_website_repository.dart';
import 'backend/control_room_repository.dart';
import 'backend/website_repository.dart';
import 'websites/website_data.dart';
import 'websites/website_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NewittApp(home: AuthStartupGate()));
}

class AuthStartupGate extends StatefulWidget {
  const AuthStartupGate({
    super.key,
    this.initializeSupabase = SupabaseConfig.initialize,
    this.authServiceBuilder,
  });

  final Future<SupabaseConnectionStatus> Function() initializeSupabase;
  final AuthenticationService Function(SupabaseConnectionStatus status)?
  authServiceBuilder;

  @override
  State<AuthStartupGate> createState() => _AuthStartupGateState();
}

class _AuthStartupGateState extends State<AuthStartupGate> {
  AuthController? _controller;
  SupabaseConnectionStatus? _status;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _status = null;
    });
    final status = await widget.initializeSupabase();
    if (!mounted) return;

    if (status != SupabaseConnectionStatus.connected) {
      setState(() {
        _status = status;
        _starting = false;
      });
      return;
    }

    final service =
        widget.authServiceBuilder?.call(status) ??
        SupabaseAuthenticationService(Supabase.instance.client);
    final controller = AuthController(
      service: service,
      developmentPreviewEnabled: false,
      hasPasswordRecoveryCallback:
          SupabaseConfig.consumePasswordRecoveryCallback(),
    );
    await controller.initialize();
    if (!mounted) {
      controller.dispose();
      return;
    }
    _controller?.dispose();
    setState(() {
      _controller = controller;
      _status = status;
      _starting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_starting) return const _StartupLoadingScreen();
    final controller = _controller;
    if (controller == null) {
      return _StartupUnavailableScreen(onRetry: _start);
    }
    return AuthGate(
      controller: controller,
      authenticatedBuilder: (session, controller) => ControlRoomHome(
        session: session,
        controller: controller,
        onLogout: controller.signOut,
        connectionStatus: _status!,
      ),
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}

class _StartupUnavailableScreen extends StatelessWidget {
  const _StartupUnavailableScreen({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Authentication unavailable',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text('The Control Room could not connect securely.'),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => onRetry(),
                child: const Text('Retry connection'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ControlRoomHome extends StatefulWidget {
  const ControlRoomHome({
    super.key,
    this.session,
    this.controller,
    this.onLogout,
    this.connectionStatus = SupabaseConnectionStatus.notConfigured,
    this.websiteRepository,
    this.controlRoomRepositoryFactory,
  });

  final AuthSession? session;
  final AuthController? controller;
  final Future<void> Function()? onLogout;
  final SupabaseConnectionStatus connectionStatus;
  final WebsiteRepository? websiteRepository;
  final ControlRoomRepositoryFactory? controlRoomRepositoryFactory;

  @override
  State<ControlRoomHome> createState() => _ControlRoomHomeState();
}

class _ControlRoomHomeState extends State<ControlRoomHome> {
  int selectedIndex = 0;
  String? _helpGuideId;
  late Future<List<Website>> _websitesFuture;

  @override
  void initState() {
    super.initState();
    _websitesFuture = _loadWebsites();
  }

  Future<List<Website>> _loadWebsites() {
    final repository =
        widget.websiteRepository ??
        (widget.connectionStatus == SupabaseConnectionStatus.connected
            ? SupabaseWebsiteRepository(Supabase.instance.client)
            : null);
    return repository?.listAccessibleWebsites() ??
        Future<List<Website>>.value(developmentWebsites);
  }

  ControlRoomRepository? get _controlRoomRepository {
    final session = widget.session;
    if (session == null) return null;
    final factory =
        widget.controlRoomRepositoryFactory ??
        (widget.connectionStatus == SupabaseConnectionStatus.connected
            ? SupabaseControlRoomRepository(Supabase.instance.client)
            : null);
    return factory?.forProfile(session.profile);
  }

  List<ControlRoomNavigationItem> get navigationItems =>
      ControlRoomNavigation.items(widget.session?.profile.role);

  @override
  Widget build(BuildContext context) {
    return HelpNavigationScope(
      onOpenGuide: _openHelpGuide,
      child: Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool mobile = constraints.maxWidth < 700;

          return Row(
            children: [
              if (!mobile)
                ControlRoomSidebar(
                  items: navigationItems,
                  selectedIndex: selectedIndex,
                  onSelected: _selectSection,
                  connectionStatus: widget.connectionStatus,
                  session: widget.session,
                  onProfile: widget.session == null ? null : _openProfile,
                ),
              Expanded(child: SafeArea(child: _buildMainContent())),
            ],
          );
        },
      ),
      bottomNavigationBar: MediaQuery.of(context).size.width < 700
          ? ControlRoomMobileNavigation(
              items: navigationItems,
              selectedIndex: selectedIndex,
              onSelected: _selectSection,
            )
          : null,
      ),
    );
  }

  void _selectSection(int index) => setState(() {
    selectedIndex = index;
    _helpGuideId = null;
  });

  void _openHelpGuide(String guideId) => setState(() {
    selectedIndex = navigationItems.indexWhere((item) => item.label == 'How To');
    _helpGuideId = guideId;
  });

  void _openProfile() {
    final session = widget.session;
    final controller = widget.controller;
    if (session == null || controller == null) return;

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AccountProfileScreen(
          session: session,
          controller: controller,
          onLogout: () {
            widget.onLogout?.call();
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildMainContent() {
    return FutureBuilder<List<Website>>(
      future: _websitesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DataErrorState(
            onRetry: () {
              setState(() => _websitesFuture = _loadWebsites());
            },
          );
        }
        return _buildSelectedContent(snapshot.data ?? const []);
      },
    );
  }

  Widget _buildSelectedContent(List<Website> websites) {
    return ControlRoomRouter.build(
      ControlRoomRouteContext(
        selectedIndex: selectedIndex,
        websites: websites,
        repository: _controlRoomRepository,
        session: widget.session,
        controller: widget.controller,
        onLogout: widget.onLogout,
        onWebsitesChanged: () {
          setState(() {
            _websitesFuture = _loadWebsites();
          });
        },
        helpGuideId: _helpGuideId,
      ),
    );
  }
}

class _DataErrorState extends StatelessWidget {
  const _DataErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 40),
          const SizedBox(height: 12),
          const Text('Unable to load Control Room data'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
