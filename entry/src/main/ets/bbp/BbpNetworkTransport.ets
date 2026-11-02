import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BbpHttpResponse } from './BbpTypes';
import { BbpHttpTransport } from './BbpHttpTransport';

function requestErrorMessage(error: Error | BusinessError | Object | string | number | boolean | null | undefined): string {
  if (error instanceof Error && error.message.trim().length > 0) {
    return error.message;
  }
  if (error !== null && typeof error === 'object') {
    const businessError = error as BusinessError;
    const code = businessError.code === undefined || businessError.code === null
      ? '' : businessError.code.toString();
    const message = businessError.message === undefined || businessError.message === null
      ? '' : businessError.message.trim();
    if (message.length > 0) {
      return code.length > 0 ? '错误码 ' + code + '：' + message : message;
    }
    const serialized = JSON.stringify(error);
    if (serialized !== undefined && serialized.length > 0 && serialized !== '{}') {
      return serialized;
    }
  }
  return '无法连接 BBP Perception 服务，请检查电脑 IP、8070 服务和防火墙';
}

export class BbpNetworkTransport implements BbpHttpTransport {
  async postJson(url: string, headers: Record<string, string>, body: string): Promise<BbpHttpResponse> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: body,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        connectTimeout: 10000,
        readTimeout: 30000,
      });
      return {
        statusCode: response.responseCode,
        body: typeof response.result === 'string' ? response.result : `${response.result ?? ''}`,
      };
    } catch (error) {
      throw new Error('BBP 网络请求失败：' + requestErrorMessage(
        error as Error | BusinessError | Object | string | number | boolean | null | undefined));
    } finally {
      request.destroy();
    }
  }

  async getJson(url: string, headers: Record<string, string>): Promise<BbpHttpResponse> {
    const request = http.createHttp();
    try {
      const response = await request.request(url, {
        method: http.RequestMethod.GET,
        header: headers,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        connectTimeout: 10000,
        readTimeout: 10000,
      });
      return {
        statusCode: response.responseCode,
        body: typeof response.result === 'string' ? response.result : `${response.result ?? ''}`,
      };
    } catch (error) {
      throw new Error('BBP 网络请求失败：' + requestErrorMessage(
        error as Error | BusinessError | Object | string | number | boolean | null | undefined));
    } finally {
      request.destroy();
    }
  }
}
