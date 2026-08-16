import {describe,expect,it} from 'vitest';
import {catalogImageError,catalogImagesError,merchantImageMaxBytes} from './merchant-image-validation';

describe('merchantImageError',()=>{
  it('accepts supported images within the limit',()=>{
    expect(catalogImageError({type:'image/webp',size:merchantImageMaxBytes})).toBe('');
  });

  it('rejects unsupported formats and oversized images',()=>{
    expect(catalogImageError({type:'image/svg+xml',size:100})).toContain('JPEG');
    expect(catalogImageError({type:'image/png',size:merchantImageMaxBytes+1})).toContain('5 MB');
  });

  it('limits a product selection to eight images',()=>{
    const files=Array.from({length:9},()=>({type:'image/jpeg',size:100}));
    expect(catalogImagesError(files)).toContain('8 imágenes');
  });
});
