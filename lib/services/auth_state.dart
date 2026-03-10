/// Simple global state to track the fake admin bypass login.
/// The web app uses localStorage('fake_admin') — this is the Flutter equivalent.
class AuthState {
  static bool isFakeAdmin = false;

  static bool get isLoggedIn => isFakeAdmin;

  static void logout() {
    isFakeAdmin = false;
  }
}
