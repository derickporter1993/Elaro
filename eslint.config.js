import lwc from "@lwc/eslint-plugin-lwc";
import babelParser from "@babel/eslint-parser";

export default [
  {
    files: ["**/*.js"],
    languageOptions: {
      parser: babelParser,
      parserOptions: {
        requireConfigFile: false,
        babelOptions: {
          parserOpts: {
            plugins: ["decorators-legacy", "classProperties"],
          },
        },
      },
      ecmaVersion: 2021,
      sourceType: "module",
      globals: {
        console: "readonly",
        document: "readonly",
        window: "readonly",
      },
    },
    plugins: {
      lwc,
    },
    rules: {
      "no-console": "warn",
      "no-unused-vars": "warn",
      "lwc/no-api-reassignments": "error",
      "lwc/no-deprecated": "warn",
      "lwc/no-document-query": "error",
      "lwc/no-inner-html": "error",
      "lwc/valid-api": "error",
      "lwc/valid-track": "error",
      "lwc/valid-wire": "error",
    },
  },
];
