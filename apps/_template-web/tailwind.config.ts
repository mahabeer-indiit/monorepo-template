import uiPreset from '@template/ui/tailwind.preset';

import type { Config } from 'tailwindcss';

export default {
  presets: [uiPreset],
  content: [
    './index.html',
    './src/**/*.{ts,tsx}',
    '../../packages/ui/src/**/*.{ts,tsx}',
  ],
} satisfies Config;
