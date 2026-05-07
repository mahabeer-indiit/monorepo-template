import { useEffect, useState } from 'react';

import { getHelloUser } from '../api/get-hello-user';

import type { User } from '@template/types';


export function useHelloUser(): User | null {
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    let cancelled = false;
    void getHelloUser().then((u) => {
      if (!cancelled) setUser(u);
    });
    return () => {
      cancelled = true;
    };
  }, []);

  return user;
}
