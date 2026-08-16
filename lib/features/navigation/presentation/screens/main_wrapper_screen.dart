import 'package:flutter/material.dart';
import 'package:ecostream/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:ecostream/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:ecostream/features/insights/presentation/screens/insights_screen.dart';
import 'package:ecostream/features/profile/presentation/screens/profile_screen.dart';
import 'package:ecostream/features/subscriptions/presentation/screens/subscriptions_screen.dart';

class MainWrapperScreen extends StatefulWidget {
  const MainWrapperScreen({super.key});

  @override
  State<MainWrapperScreen> createState() => _MainWrapperScreenState();
}

class _MainWrapperScreenState extends State<MainWrapperScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const SubscriptionsScreen(),
    const CalendarScreen(),
    const InsightsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Colors.teal),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.subscriptions_outlined),
            selectedIcon: Icon(Icons.subscriptions, color: Colors.teal),
            label: 'Assinaturas',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month, color: Colors.teal),
            label: 'Calendário',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outlined),
            selectedIcon: Icon(Icons.lightbulb, color: Colors.teal),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Colors.teal),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
