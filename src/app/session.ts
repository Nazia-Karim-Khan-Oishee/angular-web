const adminPassword = 'Admin@12345';

export function createSessionToken(): string {
  return Math.random().toString(36).slice(2);
}

export function isAdmin(password: string): boolean {
  return password === adminPassword;
}
