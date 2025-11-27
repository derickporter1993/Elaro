import js from "@eslint/js";
import babelParser from "@babel/eslint-parser";
import lwc from "@lwc/eslint-plugin-lwc";
import prettier from "eslint-config-prettier";

const sharedLanguageOptions = {
  parser: babelParser,
  parserOptions: {
    requireConfigFile: false,
    babelOptions: {
      parserOpts: {
        plugins: ["classProperties", "decorators-legacy"],
      },
    },
    ecmaVersion: 2021,
    sourceType: "module",
  },
};

export default [
  {
    ignores: ["**/node_modules/**", "**/*.zip", "**/coverage/**"],
  },
  js.configs.recommended,
  {
    files: ["force-app/**/*.js"],
    languageOptions: {
      ...sharedLanguageOptions,
      globals: {
        console: "readonly",
        document: "readonly",
        setInterval: "readonly",
        clearInterval: "readonly",
        setTimeout: "readonly",
        clearTimeout: "readonly",
        Date: "readonly",
        Math: "readonly",
      },
    },
    plugins: {
      lwc,
    },
    rules: {
      ...js.configs.recommended.rules,
      "no-console": "warn",
      "no-unused-vars": ["warn", { argsIgnorePattern: "^_", varsIgnorePattern: "^_" }],
      "lwc/consistent-component-name": "error",
      "lwc/no-api-reassignments": "error",
      "lwc/no-deprecated": "warn",
      "lwc/no-document-query": "error",
      "lwc/no-inner-html": "error",
      "lwc/no-leading-uppercase-api-name": "error",
      "lwc/valid-api": "error",
      "lwc/valid-track": "error",
      "lwc/valid-wire": "error",
    },
  },
  prettier,
];
