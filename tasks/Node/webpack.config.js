module.exports = {
  mode: "development",
  devtool: "source-map",
//  mode: "production",
//  devtool: false,//"source-map",
  target: "node",
  entry: {
    AzureDtlCreateCustomImage: "./src/tasks/AzureDtlCreateCustomImage/task.ts",
    AzureDtlCreateEnvironment: "./src/tasks/AzureDtlCreateEnvironment/task.ts",
    AzureDtlCreateVM: "./src/tasks/AzureDtlCreateVM/task.ts",
    AzureDtlDeleteEnvironment: "./src/tasks/AzureDtlDeleteEnvironment/task.ts",
    AzureDtlDeleteVM: "./src/tasks/AzureDtlDeleteVM/task.ts",
    AzureDtlUpdateEnvironment: "./src/tasks/AzureDtlUpdateEnvironment/task.ts"
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
