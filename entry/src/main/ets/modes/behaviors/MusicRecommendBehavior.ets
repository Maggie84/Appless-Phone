import { A2uiGenericToolResultData, A2uiGenericToolResultRowData } from '@loop/agent-core';
import { ModeContext, ModeBehavior } from '../core/ModeBehavior';
import { ModeBehaviorResult } from '../core/ModeTypes';

const BILIBILI_BVID = 'BV1WZ4y1K7pL';
const BILIBILI_WATCH_URL = 'https://www.bilibili.com/video/' + BILIBILI_BVID;
const YOUTUBE_VIDEO_ID = 'FcGrfS4BOhY';
const YOUTUBE_WATCH_URL = 'https://www.youtube.com/watch?v=' + YOUTUBE_VIDEO_ID;

export class MusicRecommendBehavior implements ModeBehavior {
  readonly name = 'music-recommend';
  readonly displayName = '推荐舒缓音乐';

  async execute(_ctx: ModeContext): Promise<ModeBehaviorResult> {
    const bilibiliRows: A2uiGenericToolResultRowData[] = [
      { label: '曲目', value: '林海 - 月光边境' },
      { label: 'Watch URL', value: BILIBILI_WATCH_URL },
      { label: 'BVID', value: BILIBILI_BVID },
    ];

    const bilibiliResult: A2uiGenericToolResultData = {
      sourceTag: '哔哩哔哩',
      toolName: 'media.video.search',
      title: '林海 - 月光边境（B站）',
      status: 'success',
      summary: 'B站推荐，播放器内直接播放',
      rows: bilibiliRows,
      rawPreview: '',
      actions: [],
    };

    const youtubeRows: A2uiGenericToolResultRowData[] = [
      { label: '曲目', value: '林海 - 月光边境' },
      { label: 'Watch URL', value: YOUTUBE_WATCH_URL },
      { label: 'Video ID', value: YOUTUBE_VIDEO_ID },
    ];

    const youtubeResult: A2uiGenericToolResultData = {
      sourceTag: 'YouTube Data API',
      toolName: 'youtube.video.search',
      title: '林海 - 月光边境（YouTube）',
      status: 'success',
      summary: 'YouTube 备用源',
      rows: youtubeRows,
      rawPreview: '',
      actions: [],
    };

    return {
      ok: true,
      message: '已为你推荐舒缓纯音乐',
      toolResults: [bilibiliResult, youtubeResult],
    };
  }
}