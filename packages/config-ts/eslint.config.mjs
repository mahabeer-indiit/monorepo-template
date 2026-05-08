// config-ts ships only .json + .md — no source for ESLint to lint.
// We still expose a `lint` script so turbo's pipeline runs uniformly across packages;
// `--no-error-on-unmatched-pattern` keeps it green when nothing matches.
import config from '@template/config-eslint/node.mjs';

export default config;
