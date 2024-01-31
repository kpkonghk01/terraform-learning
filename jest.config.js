/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  moduleNameMapper: {
    "^/opt/nodejs/(.*)": "<rootDir>/src/layers/$1",
  },
  transform: {
    "^.+\\.(ts|js)x?$": "ts-jest",
  },
};
