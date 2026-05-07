import { useState } from 'react';

import { HelloButton } from '../components/HelloButton';
import { useHelloUser } from '../hooks/use-hello-user';

export function HelloPage() {
  const user = useHelloUser();
  const [greeting, setGreeting] = useState<string | null>(null);

  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col items-center justify-center gap-6 p-8">
      <h1 className="text-4xl font-semibold">Template Web</h1>
      <p className="text-muted-foreground">
        End-to-end wiring: <code>@template/ui</code> + <code>@template/types</code> in a feature
        module.
      </p>

      {user ? (
        <p className="text-sm">
          Loaded user <strong>{user.email}</strong> (id: <code>{user.id}</code>)
        </p>
      ) : (
        <p className="text-sm text-muted-foreground">Loading user…</p>
      )}

      <HelloButton onGreet={() => setGreeting(user ? `Hello, ${user.email}` : 'Hello!')} />

      {greeting !== null && <p className="text-lg">{greeting}</p>}
    </main>
  );
}
