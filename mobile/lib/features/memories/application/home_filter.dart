import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The group chosen in the Home filter; null means all circles. The shell
/// uses it so "New Memory" opens with the audience already in view.
final homeGroupFilterProvider = NotifierProvider<HomeGroupFilter, String?>(
  HomeGroupFilter.new,
);

class HomeGroupFilter extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? groupId) => state = groupId;
}
