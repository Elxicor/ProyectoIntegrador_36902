import { ArgumentMetadata, Injectable, PipeTransform } from '@nestjs/common';

@Injectable()
export class CedulaPipe implements PipeTransform {
  transform(value: any, _metadata: ArgumentMetadata) {
    return value;
  }
}
