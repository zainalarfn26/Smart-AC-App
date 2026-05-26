import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'routes/app_routes.dart';
import 'package:provider/provider.dart';
import 'controllers/mqtt_controller.dart';
import 'controllers/theme_controller.dart';
import 'core/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MqttController()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
      ],
      child: Consumer<ThemeController>(
        builder: (context, themeController, child) {
          // Update system UI based on theme
          SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: themeController.isDarkMode 
                ? Brightness.light 
                : Brightness.dark,
            systemNavigationBarColor: themeController.isDarkMode 
                ? AppColors.surfaceDark 
                : AppColors.surfaceLight,
            systemNavigationBarIconBrightness: themeController.isDarkMode 
                ? Brightness.light 
                : Brightness.dark,
          ));
          
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Smart AC Control',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeController.themeMode,
            initialRoute: AppRoutes.authGate,
            routes: AppRoutes.routes,
          );
        },
      ),
    );
  }
}