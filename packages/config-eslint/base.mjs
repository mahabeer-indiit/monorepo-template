import js from '@eslint/js';
import prettierConfig from 'eslint-config-prettier';
import importPlugin from 'eslint-plugin-import';
import unusedImports from 'eslint-plugin-unused-imports';
import tseslint from 'typescript-eslint';

export default [
  {
    ignores: [
      '**/dist/**',
      '**/build/**',
      '**/.next/**',
      '**/.expo/**',
      '**/.turbo/**',
      '**/coverage/**',
      '**/node_modules/**',
      '**/*.tsbuildinfo',
    ],
  },

  js.configs.recommended,
  ...tseslint.configs.recommended,

  {
    files: ['**/*.{ts,tsx,mts,cts,js,jsx,mjs,cjs}'],
    plugins: {
      import: importPlugin,
      'unused-imports': unusedImports,
    },
    settings: {
      // Use only the node resolver (with TS extensions). The typescript resolver
      // walks the tsconfig `extends` chain and doesn't follow pnpm's symlinks
      // when computing relative paths, so chains like
      // app/tsconfig → @template/config-ts/base.json → ../../tsconfig.base.json
      // crash with "Tsconfig not found node_modules/tsconfig.base.json" inside
      // any consuming app. Node resolution doesn't have this problem.
      // Trade-off: tsconfig `paths` (e.g. `@/foo`) won't be resolved by lint —
      // import/order still sorts them correctly by string, and import/no-cycle
      // simply skips unresolvable imports rather than crashing.
      'import/resolver': {
        node: {
          extensions: ['.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs'],
        },
      },
    },
    rules: {
      'import/order': [
        'error',
        {
          // No 'type' group — type imports interleave naturally with their
          // value-import counterparts (sorted by source within each group).
          groups: [
            'builtin',
            'external',
            'internal',
            ['parent', 'sibling', 'index'],
            'object',
          ],
          'newlines-between': 'always',
          alphabetize: { order: 'asc', caseInsensitive: true },
        },
      ],
      'import/no-cycle': ['error', { maxDepth: 10, ignoreExternal: true }],
      'import/no-duplicates': 'error',
      'unused-imports/no-unused-imports': 'error',
      'unused-imports/no-unused-vars': [
        'warn',
        {
          vars: 'all',
          varsIgnorePattern: '^_',
          args: 'after-used',
          argsIgnorePattern: '^_',
        },
      ],
      '@typescript-eslint/no-unused-vars': 'off',
    },
  },

  // Ban new .js/.jsx files inside any src/ directory.
  // The Program selector matches the entire file, so the message fires once per offending file.
  {
    files: ['**/src/**/*.{js,jsx,cjs,mjs}'],
    rules: {
      'no-restricted-syntax': [
        'error',
        {
          selector: 'Program',
          message:
            'JavaScript files are not allowed in src/. Use TypeScript (.ts / .tsx) instead.',
        },
      ],
    },
  },

  prettierConfig,
];
