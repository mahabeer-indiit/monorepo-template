import type { User } from '@template/types';

export type HelloUser = Pick<User, 'id' | 'email'>;
