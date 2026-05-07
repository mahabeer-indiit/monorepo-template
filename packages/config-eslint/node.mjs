import globals from 'globals';

import baseConfig from './base.mjs';

export default [
  ...baseConfig,
  {
    files: ['**/*.{js,mjs,cjs,ts,mts,cts}'],
    languageOptions: {
      globals: { ...globals.node, ...globals.nodeBuiltin },
      sourceType: 'module',
    },
  },
];
