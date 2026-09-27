/// Sign-in with email and password (the login page, sign-up and log-out). Off for now: players get an
/// anonymous profile on their first online match and only choose a nickname. The email flow is kept for when
/// profiles can be saved across devices; turn it on with `--dart-define=EMAIL_ACCOUNTS=true`.
const emailAccountsEnabled = bool.fromEnvironment('EMAIL_ACCOUNTS');
