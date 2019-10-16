import 'isomorphic-fetch';

if (!console.debug) {
    const isDebugMode = process.env.NODE_ENV != 'production';

    console.debug = function (args: any) {
        if (isDebugMode) {
            console.log(args);
        }
    }
}

export function equalsIgnoreCase(s1: string|null|undefined, s2: string|null|undefined): boolean {
    return s1 === s2 || (s1 !== null && s1 !== undefined && s2 !== null && s2 !== undefined && s1.toLocaleLowerCase() === s2.toLocaleLowerCase());
}