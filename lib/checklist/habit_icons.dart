import 'package:flutter/material.dart';

class HabitIconChoice {
  const HabitIconChoice(this.key, this.icon, this.label, this.category);
  final String key, label, category;
  final IconData icon;
}

const habitIcons = <HabitIconChoice>[
  HabitIconChoice('leaf', Icons.spa_outlined, 'Leaf', 'Legacy'),
  HabitIconChoice('water', Icons.local_drink_outlined, 'Water', 'Legacy'),
  HabitIconChoice('book', Icons.menu_book_outlined, 'Book', 'Legacy'),
  HabitIconChoice('money', Icons.savings_outlined, 'Money', 'Legacy'),
  HabitIconChoice('move', Icons.directions_run_outlined, 'Move', 'Legacy'),
  HabitIconChoice('heart', Icons.favorite_outline, 'Heart', 'Legacy'),
  HabitIconChoice('moon', Icons.nightlight_round, 'Moon', 'Legacy'),
  HabitIconChoice(
      'meditate', Icons.self_improvement_outlined, 'Meditate', 'Legacy'),
  HabitIconChoice('hydration', Icons.local_drink, 'Hydration', 'Health'),
  HabitIconChoice('walk', Icons.directions_walk, 'Walk', 'Health'),
  HabitIconChoice('run', Icons.directions_run, 'Run', 'Health'),
  HabitIconChoice('cycling', Icons.directions_bike, 'Cycling', 'Health'),
  HabitIconChoice('gym', Icons.fitness_center, 'Gym', 'Health'),
  HabitIconChoice('yoga', Icons.self_improvement, 'Yoga', 'Health'),
  HabitIconChoice('sleep', Icons.hotel, 'Sleep', 'Health'),
  HabitIconChoice('healthy_food', Icons.restaurant, 'Healthy food', 'Health'),
  HabitIconChoice('medicine', Icons.medication, 'Medicine', 'Health'),
  HabitIconChoice('dental', Icons.cleaning_services, 'Dental', 'Health'),
  HabitIconChoice('stretch', Icons.accessibility_new, 'Stretch', 'Health'),
  HabitIconChoice('steps', Icons.hiking, 'Steps', 'Health'),
  HabitIconChoice('reading', Icons.auto_stories, 'Reading', 'Study'),
  HabitIconChoice('study', Icons.school, 'Study', 'Study'),
  HabitIconChoice('writing', Icons.edit, 'Writing', 'Study'),
  HabitIconChoice('language', Icons.translate, 'Language', 'Study'),
  HabitIconChoice('coding', Icons.code, 'Coding', 'Study'),
  HabitIconChoice('research', Icons.science, 'Research', 'Study'),
  HabitIconChoice('class', Icons.cast_for_education, 'Class', 'Study'),
  HabitIconChoice('journal', Icons.edit_note, 'Journal', 'Study'),
  HabitIconChoice('flashcards', Icons.style, 'Flashcards', 'Study'),
  HabitIconChoice('exam', Icons.quiz, 'Exam', 'Study'),
  HabitIconChoice('focus', Icons.center_focus_strong, 'Focus', 'Work'),
  HabitIconChoice('planning', Icons.event_note, 'Planning', 'Work'),
  HabitIconChoice('work', Icons.work_outline, 'Work', 'Work'),
  HabitIconChoice('meeting', Icons.groups, 'Meeting', 'Work'),
  HabitIconChoice('finance', Icons.account_balance, 'Finance', 'Work'),
  HabitIconChoice('budget', Icons.account_balance_wallet, 'Budget', 'Work'),
  HabitIconChoice('email', Icons.mail_outline, 'Email', 'Work'),
  HabitIconChoice('time', Icons.schedule, 'Time', 'Work'),
  HabitIconChoice('goal', Icons.flag, 'Goal', 'Work'),
  HabitIconChoice('organize', Icons.checklist, 'Organize', 'Work'),
  HabitIconChoice('clean', Icons.cleaning_services, 'Clean', 'Home'),
  HabitIconChoice('laundry', Icons.local_laundry_service, 'Laundry', 'Home'),
  HabitIconChoice('cook', Icons.soup_kitchen, 'Cook', 'Home'),
  HabitIconChoice('garden', Icons.yard, 'Garden', 'Home'),
  HabitIconChoice('pets', Icons.pets, 'Pets', 'Home'),
  HabitIconChoice('family', Icons.family_restroom, 'Family', 'Home'),
  HabitIconChoice('shopping', Icons.shopping_basket, 'Shopping', 'Home'),
  HabitIconChoice('commute', Icons.commute, 'Commute', 'Home'),
  HabitIconChoice('recycle', Icons.recycling, 'Recycle', 'Home'),
  HabitIconChoice('minimalism', Icons.inventory_2, 'Minimalism', 'Home'),
  HabitIconChoice('breathing', Icons.air, 'Breathing', 'Mindfulness'),
  HabitIconChoice(
      'gratitude', Icons.volunteer_activism, 'Gratitude', 'Mindfulness'),
  HabitIconChoice('prayer', Icons.spa, 'Prayer', 'Mindfulness'),
  HabitIconChoice(
      'meditation', Icons.self_improvement, 'Meditation', 'Mindfulness'),
  HabitIconChoice('music', Icons.music_note, 'Music', 'Mindfulness'),
  HabitIconChoice('art', Icons.palette, 'Art', 'Mindfulness'),
  HabitIconChoice(
      'photography', Icons.photo_camera, 'Photography', 'Mindfulness'),
  HabitIconChoice('gaming', Icons.sports_esports, 'Gaming', 'Mindfulness'),
  HabitIconChoice('craft', Icons.handyman, 'Craft', 'Mindfulness'),
  HabitIconChoice('social', Icons.forum, 'Social', 'Mindfulness'),
];
IconData habitIcon(String key) =>
    habitIcons.where((i) => i.key == key).firstOrNull?.icon ??
    Icons.spa_outlined;
