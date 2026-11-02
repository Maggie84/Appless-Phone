import { BbpHttpResponse } from './BbpTypes';

export interface BbpHttpTransport {
  postJson(url: string, headers: Record<string, string>, body: string): Promise<BbpHttpResponse>;
  getJson(url: string, headers: Record<string, string>): Promise<BbpHttpResponse>;
}
