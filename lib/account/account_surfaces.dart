import 'package:flutter/material.dart';

class AccountPanel extends StatelessWidget {
  const AccountPanel(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Material(
        color: const Color(0xFF10272C),
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: Color(0xFF294247)),
            borderRadius: BorderRadius.circular(22)),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      );
}

class AccountActionTile extends StatelessWidget {
  const AccountActionTile(
      {super.key,
      required this.title,
      required this.icon,
      this.subtitle,
      this.onTap,
      this.danger = false});
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFFFB4AB) : const Color(0xFFB1D6C8);
    return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(13)),
                  child: Icon(icon, color: color, size: 21)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: danger ? color : null)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!,
                          style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFFABC1BB))),
                    ],
                  ])),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 20, color: color),
            ]),
          ),
        ));
  }
}
