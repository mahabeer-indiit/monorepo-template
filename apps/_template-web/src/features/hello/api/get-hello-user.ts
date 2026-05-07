import type { User } from '@template/types';

export async function getHelloUser(): Promise<User> {
  return {
    id: 'demo-user',
    email: 'hello@example.com',
    createdAt: new Date(),
  };
}
