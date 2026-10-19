/** Public verifier types. T is the caller's verified digest contract; runtime schema validation remains mandatory. */
export type ReaderCache<T> = {load():Promise<T|null>;save(value:T):Promise<void>};
export declare function encodePublicJSON(value:unknown):Uint8Array;
export declare function publicContentHash(bytes:Uint8Array):Promise<string>;
export declare function verifyClientDigest(value:unknown):Promise<void>;
export declare class ClientDataReader<T = unknown> {
  constructor(options:{baseUrl:string;fetcher?:typeof fetch;cache?:ReaderCache<T>});
  readonly baseUrl:URL;
  readonly fetcher:typeof fetch;
  readonly cache?:ReaderCache<T>;
  current:T|null;
  refresh():Promise<{state:'current'|'last-good'|'unavailable';digest:T|null;errorCode:string|null}>;
}
