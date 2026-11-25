import 'dart:math';
import '../models/image_item.dart';

class FFmpegAnimationFilterBuilder {
  static String buildClipFilter({
    required ImageItem item,
    required int width,
    required int height,
    int fps = 30,
  }) {
    final filters = <String>[];
    final t = item.transform;

    // Base scaling and aspect ratio framing
    final sW = (width * t.scaleX).round().clamp(10, width * 5);
    final sH = (height * t.scaleY).round().clamp(10, height * 5);
    filters.add('scale=$sW:$sH:force_original_aspect_ratio=decrease');

    // Dead-center padding: guarantees the asset is centered with zero drift
    final offX = (t.positionX * width * 0.5).round();
    final offY = (t.positionY * height * 0.5).round();
    final xExpr = offX != 0 ? '(ow-iw)/2+$offX' : '(ow-iw)/2';
    final yExpr = offY != 0 ? '(oh-ih)/2+$offY' : '(oh-ih)/2';
    filters.add('pad=$width:$height:$xExpr:$yExpr:color=black');
    filters.add('setsar=1');

    if (t.rotation != 0) {
      filters.add('rotate=${t.rotation}:ow=$width:oh=$height:c=black');
    }

    // Apply active animations with centered zoom, rotation, and smooth opacity transitions
    final durSec = max(0.1, item.durationMs / 1000.0);
    for (final anim in item.animations) {
      final aSec = (anim.durationMs / 1000.0).clamp(0.1, durSec);
      switch (anim.presetId) {
        case 'fadeIn':
          if (!anim.isExit) {
            filters.add('fade=t=in:st=0:d=$aSec');
          } else {
            final st = max(0.0, durSec - aSec);
            filters.add('fade=t=out:st=$st:d=$aSec');
          }
          break;
        case 'fadeOut':
          final st = max(0.0, durSec - aSec);
          filters.add('fade=t=out:st=$st:d=$aSec');
          break;
        case 'zoomIn':
          filters.add('fade=t=in:st=0:d=$aSec');
          filters.add("zoompan=z='min(1.25, 1.0+0.25*on/($fps*$durSec))':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'zoomOutEntrance':
          filters.add('fade=t=in:st=0:d=$aSec');
          filters.add("zoompan=z='max(1.0, 1.30-0.30*on/($fps*$aSec))':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slowZoomIn':
          filters.add("zoompan=z='min(1.18, 1.0+0.18*on/($fps*$durSec))':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'zoomOutExit':
          final stOut = max(0.0, durSec - aSec);
          filters.add('fade=t=out:st=$stOut:d=$aSec');
          filters.add("zoompan=z='if(gte(on, $fps*$stOut), max(1.0, 1.25-0.25*(on-$fps*$stOut)/($fps*$aSec)), 1.25)':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slowZoomOut':
          filters.add("zoompan=z='max(1.0, 1.18-0.18*on/($fps*$durSec))':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'shrinkOut':
          final stShrink = max(0.0, durSec - aSec);
          filters.add('fade=t=out:st=$stShrink:d=$aSec');
          filters.add("zoompan=z='if(gte(on, $fps*$stShrink), max(0.1, 1.0-(on-$fps*$stShrink)/($fps*$aSec)), 1.0)':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'pulseZoom':
          filters.add("zoompan=z='1.0+0.06*sin(2*PI*on/($fps*1.5))':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'bounceIn':
        case 'popIn':
          filters.add('fade=t=in:st=0:d=$aSec');
          filters.add("zoompan=z='min(1.15, 0.88+0.27*on/($fps*$aSec))':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slideInLeft':
          filters.add('fade=t=in:st=0:d=$aSec');
          filters.add("zoompan=z=1.12:x='(iw-iw/zoom)*(min(1.0, on/($fps*$aSec)))':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slideInRight':
          filters.add('fade=t=in:st=0:d=$aSec');
          filters.add("zoompan=z=1.12:x='(iw-iw/zoom)*(1.0-min(1.0, on/($fps*$aSec)))':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slideInTop':
          filters.add('fade=t=in:st=0:d=$aSec');
          filters.add("zoompan=z=1.12:x='(iw-iw/zoom)/2':y='(ih-ih/zoom)*(min(1.0, on/($fps*$aSec)))':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slideInBottom':
          filters.add('fade=t=in:st=0:d=$aSec');
          filters.add("zoompan=z=1.12:x='(iw-iw/zoom)/2':y='(ih-ih/zoom)*(1.0-min(1.0, on/($fps*$aSec)))':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slideOutLeft':
          final stOutL = max(0.0, durSec - aSec);
          filters.add('fade=t=out:st=$stOutL:d=$aSec');
          filters.add("zoompan=z=1.12:x='if(gte(on, $fps*$stOutL), (iw-iw/zoom)*(1.0-(on-$fps*$stOutL)/($fps*$aSec)), (iw-iw/zoom)/2)':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slideOutRight':
          final stOutR = max(0.0, durSec - aSec);
          filters.add('fade=t=out:st=$stOutR:d=$aSec');
          filters.add("zoompan=z=1.12:x='if(gte(on, $fps*$stOutR), (iw-iw/zoom)*((on-$fps*$stOutR)/($fps*$aSec)), (iw-iw/zoom)/2)':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slideOutTop':
          final stOutT = max(0.0, durSec - aSec);
          filters.add('fade=t=out:st=$stOutT:d=$aSec');
          filters.add("zoompan=z=1.12:x='(iw-iw/zoom)/2':y='if(gte(on, $fps*$stOutT), (ih-ih/zoom)*(1.0-(on-$fps*$stOutT)/($fps*$aSec)), (ih-ih/zoom)/2)':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'slideOutBottom':
          final stOutB = max(0.0, durSec - aSec);
          filters.add('fade=t=out:st=$stOutB:d=$aSec');
          filters.add("zoompan=z=1.12:x='(iw-iw/zoom)/2':y='if(gte(on, $fps*$stOutB), (ih-ih/zoom)*((on-$fps*$stOutB)/($fps*$aSec)), (ih-ih/zoom)/2)':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'moveLeft':
          filters.add("zoompan=z=1.15:x='(iw-iw/zoom)*(1.0-on/($fps*$durSec))':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'moveRight':
          filters.add("zoompan=z=1.15:x='(iw-iw/zoom)*(on/($fps*$durSec))':y='(ih-ih/zoom)/2':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'moveUp':
          filters.add("zoompan=z=1.15:x='(iw-iw/zoom)/2':y='(ih-ih/zoom)*(1.0-on/($fps*$durSec))':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'moveDown':
          filters.add("zoompan=z=1.15:x='(iw-iw/zoom)/2':y='(ih-ih/zoom)*(on/($fps*$durSec))':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'drift':
          filters.add("zoompan=z='1.06+0.06*on/($fps*$durSec)':x='(iw-iw/zoom)*(0.2+0.6*on/($fps*$durSec))':y='(ih-ih/zoom)*(0.2+0.6*on/($fps*$durSec))':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'shake':
          filters.add("zoompan=z=1.06:x='(iw-iw/zoom)*(0.5+0.15*sin(on*0.7))':y='(ih-ih/zoom)*(0.5+0.15*cos(on*0.9))':d=1:s=${width}x$height:fps=$fps");
          break;
        case 'wobble':
          filters.add("rotate='0.05*sin(8*PI*t/$durSec)':ow=$width:oh=$height:c=black");
          break;
        case 'rocking':
          filters.add("rotate='0.08*sin(2*PI*t/2)':ow=$width:oh=$height:c=black");
          break;
        case 'rotateClockwise':
          filters.add("rotate='2*PI*t/$durSec':ow=$width:oh=$height:c=black");
          break;
        case 'rotateCounterClockwise':
          filters.add("rotate='-2*PI*t/$durSec':ow=$width:oh=$height:c=black");
          break;
        case 'rotateIn':
          filters.add('fade=t=in:st=0:d=$aSec');
          filters.add("rotate='-(1.0-min(1,t/$aSec))*0.5':ow=$width:oh=$height:c=black");
          break;
        case 'continuousRotation':
          filters.add("rotate='2*PI*t/3':ow=$width:oh=$height:c=black");
          break;
      }
    }

    return filters.join(',');
  }
}
