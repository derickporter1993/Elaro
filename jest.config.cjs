const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
  ...jestConfig,
  modulePathIgnorePatterns: [],
  testPathIgnorePatterns: ["<rootDir>/node_modules/"],
};
