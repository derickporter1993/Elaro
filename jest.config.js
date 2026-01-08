import { jestConfig } from "@salesforce/sfdx-lwc-jest/config.js";

export default {
  ...jestConfig,
  modulePathIgnorePatterns: ["<rootDir>/.localdevserver", "<rootDir>/Sentinel-main/"],
  testPathIgnorePatterns: ["<rootDir>/node_modules/", "<rootDir>/Sentinel-main/"],
};
