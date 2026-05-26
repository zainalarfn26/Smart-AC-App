import 'package:flutter/material.dart';
import '../views/pages/auth_gate_page.dart';
import '../views/pages/home_page.dart';
import '../views/pages/add_room_page.dart';
import '../views/pages/history_page.dart';
import '../views/pages/login_page.dart';
import '../views/pages/register_page.dart';

class AppRoutes {
  static const authGate = '/auth-gate';
  static const home = '/';
  static const addRoom = '/add-room';
  static const history = '/history';
  static const login = '/login';
  static const register = '/register';

  static Map<String, WidgetBuilder> routes = {
    authGate: (context) => const AuthGatePage(),
    home: (context) => const HomePage(),
    addRoom: (context) => const AddRoomPage(),
    history: (context) => const HistoryPage(),
    login: (context) => const LoginPage(),
    register: (context) => const RegisterPage(),
  };
}