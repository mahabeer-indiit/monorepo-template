import type { Config } from 'tailwindcss';

import preset from './tailwind.preset';

/**
 * Local Tailwind config — used by the shadcn CLI when running `shadcn add`
 * inside this package. Apps consuming the library should extend the
 * `tailwind.preset` instead.
 */
const config: Config = {
  ...preset,
  content: ['./src/**/*.{ts,tsx}'],
};

export default config;
