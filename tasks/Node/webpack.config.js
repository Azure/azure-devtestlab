const TerserPlugin = require("terser-webpack-plugin");

module.exports = {
  mode: "production",
  devtool: false,
  target: "node",
  entry: {
    AzureDtlCreateCustomImage: "./src/tasks/AzureDtlCreateCustomImage/task.ts",
    AzureDtlCreateEnvironment: "./src/tasks/AzureDtlCreateEnvironment/task.ts",
    AzureDtlCreateVM: "./src/tasks/AzureDtlCreateVM/task.ts",
    AzureDtlDeleteCustomImage: "./src/tasks/AzureDtlDeleteCustomImage/task.ts",
    AzureDtlDeleteEnvironment: "./src/tasks/AzureDtlDeleteEnvironment/task.ts",
    AzureDtlDeleteVM: "./src/tasks/AzureDtlDeleteVM/task.ts",
    AzureDtlUpdateEnvironment: "./src/tasks/AzureDtlUpdateEnvironment/task.ts"
  },
  optimization: {
    minimizer: [
      new TerserPlugin({
        parallel: true,
        terserOptions: {
          keep_classnames: /AbortSignal/,
          keep_fnames: /AbortSignal/,
        },
      }),
    ],
  },
  output: {
    path: __dirname + "/dist/",
    filename: "tasks/[name]/task.js"
  },
  resolve: {
    extensions: [".ts", ".tsx", ".js"]
  },
  module: {
    rules: [
      // all files with a `.ts` or `.tsx` extension will be handled by `ts-loader`
      { test: /\.tsx?$/, loader: "ts-loader" }
    ]
  }
};