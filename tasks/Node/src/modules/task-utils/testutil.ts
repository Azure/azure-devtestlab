import fs from 'fs';
import path from 'path';
import util from 'util';

import * as tl from 'azure-pipelines-task-lib/task';

export async function getTestData(): Promise<any> {
    try {
        const parentFileName = module.parent ? module.parent.filename : null;
        if (!parentFileName) {
            throw 'TestUtil: Expectation is that this function is called from a parent module.';
        }

        tl.debug(`TestUtil: Getting test data for module '${path.relative(process.cwd(), parentFileName)}'.`)
        const testDataFilePath = path.join(path.dirname(parentFileName), 'testdata.json');

        tl.debug(`TestUtil: Getting test data from test file '${path.relative(process.cwd(), testDataFilePath)}'.`)
        const fsReadFile = util.promisify(fs.readFile);
        const data = await fsReadFile(testDataFilePath, 'utf8');

        return JSON.parse(data);
    }
    catch (error) {
        tl.error(error);
    }
}