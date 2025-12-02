import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/profile_service.dart';

enum ProfileLoadingState {
  initial,
  loading,
  loaded,
  error,
  saving,
}

class ProfileProvider extends ChangeNotifier {
  ProfileLoadingState _state = ProfileLoadingState.initial;
  UserProfile? _profile;
  String? _errorMessage;

  ProfileLoadingState get state => _state;
  UserProfile? get profile => _profile;
  String? get errorMessage => _errorMessage;
  bool get hasProfile => _profile != null;
  bool get isLoading => _state == ProfileLoadingState.loading;
  bool get isSaving => _state == ProfileLoadingState.saving;

  Future<void> loadProfile() async {
    try {
      _setState(ProfileLoadingState.loading);
      
      final profile = await ProfileService.getCurrentUserProfile();
      
      _profile = profile;
      _setState(ProfileLoadingState.loaded);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(ProfileLoadingState.error);
    }
  }

  Future<bool> saveProfile(UserProfile profile) async {
    try {
      _setState(ProfileLoadingState.saving);
      
      await ProfileService.saveUserProfile(profile);
      
      _profile = profile;
      _setState(ProfileLoadingState.loaded);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _setState(ProfileLoadingState.error);
      return false;
    }
  }

  Future<void> deleteProfile() async {
    try {
      _setState(ProfileLoadingState.loading);
      
      await ProfileService.deleteUserProfile();
      
      _profile = null;
      _setState(ProfileLoadingState.loaded);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(ProfileLoadingState.error);
    }
  }

  void _setState(ProfileLoadingState newState) {
    _state = newState;
    if (newState != ProfileLoadingState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == ProfileLoadingState.error) {
      _state = _profile != null ? ProfileLoadingState.loaded : ProfileLoadingState.initial;
    }
    notifyListeners();
  }

  void clear() {
    _profile = null;
    _errorMessage = null;
    _state = ProfileLoadingState.initial;
    notifyListeners();
  }
}