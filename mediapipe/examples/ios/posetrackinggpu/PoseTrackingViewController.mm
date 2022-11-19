// Copyright 2020 The MediaPipe Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "PoseTrackingViewController.h"

#include "mediapipe/framework/formats/landmark.pb.h"

static const char* kLandmarksOutputStream = "pose_landmarks";

@implementation PoseTrackingViewController

#pragma mark - UIViewController methods

- (void)viewDidLoad {
  [super viewDidLoad];
  
  // init
  maxAngle = 10;
  toleranceCoefficient = 3.0;
  matchPmsKeys = @[@"angle11to13", @"angle12to14", @"angle13to15",  @"angle14to16", @"angle23to25", @"angle24to26", @"angle25to27", @"angle26to28"];
  
  // get date string
  NSDate *currentDate = [NSDate date];
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"YYYY-MM-dd_HH_mm_ss"];
  NSString *dateString = [dateFormatter stringFromDate:currentDate];
  
  // load json from https url
  NSError *error;
  NSString *url_string = [NSString stringWithFormat: @"https://ldn-t.oss.tinycloud.uk/poseDataList.json?t=%@", dateString];
//    NSData *data = [NSData dataWithContentsOfURL: [NSURL URLWithString:url_string]];
  NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url_string] options:NSDataReadingUncached error:&error];
  if (error) {
     NSLog(@"%@", [error localizedDescription]);
  } else {
     NSLog(@"Data has loaded successfully.");
  }
  jsonPoseDataList = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
  NSLog(@"json: %@", jsonPoseDataList);
  NSUInteger cntMatchPmsKeys = matchPmsKeys.count;
  NSUInteger count = jsonPoseDataList.count;
  for(int i=0; i<count; i++){
      id obj = [jsonPoseDataList objectAtIndex:i];
      NSLog(@"%i-%@",i, obj);
      if ([obj isKindOfClass:[NSDictionary class]]){
        NSDictionary *dict = (NSDictionary *)obj;
        NSLog(@"Dersialized JSON Dictionary = %@", dict);
          for(int j=0; j<cntMatchPmsKeys; j++) {
              id keyName = [matchPmsKeys objectAtIndex:j];
              if([keyName isKindOfClass:[NSString class]]) {
                  NSString *strKeyName = (NSString *)keyName;
                  NSLog(@"pose: %d key: %@的值是:%f", i, strKeyName,[[dict objectForKey:strKeyName] doubleValue]);
                  NSLog(@"pose: %d key: %@的值是:%f", i, strKeyName,[dict[@"angles"][strKeyName] doubleValue]);
                  NSLog(@"pose: %d key: %@的值是:%f", i, strKeyName,[obj[@"angles"][strKeyName] doubleValue]);
              }
          }
          NSLog(@"pose: %d key name的值是:%f", i, [[dict objectForKey:@"angle11to13"] floatValue]);
      }
  }
      
//    NSString *path = [@"http://ldn-t.oss.tinycloud.uk/poseDataList.json" stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
//    NSError *error;
//    NSString *url_string = [NSString stringWithFormat: @"http://ldn-t.oss.tinycloud.uk/poseDataList.json"];
//    NSData *data = [NSData dataWithContentsOfURL: [NSURL URLWithString:url_string]];
//    NSData* data = [NSData dataWithContentsOfURL:[NSURL URLWithString:url_string] options:NSDataReadingUncached error:&error];
//    if (error) {
//       NSLog(@"%@", [error localizedDescription]);
//    } else {
//       NSLog(@"Data has loaded successfully.");
//    }
//    NSMutableArray *json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
//    NSLog(@"json: %@", json);

// download synchronous way
//    NSData *theData = [NSURLConnection sendSynchronousRequest:request
//                          returningResponse:nil
//                                      error:nil];
//
//    NSDictionary *newJSON = [NSJSONSerialization JSONObjectWithData:theData
//                                                            options:0
//                                                              error:nil];
//
//    NSLog(@"Sync JSON: %@", newJSON);


  [self.mediapipeGraph addFrameOutputStream:kLandmarksOutputStream
                           outputPacketType:MPPPacketTypeRaw];
}

#pragma mark - MPPGraphDelegate methods

// Receives a raw packet from the MediaPipe graph. Invoked on a MediaPipe worker thread.
- (void)mediapipeGraph:(MPPGraph*)graph
     didOutputPacket:(const ::mediapipe::Packet&)packet
          fromStream:(const std::string&)streamName {
  if (streamName == kLandmarksOutputStream) {
    if (packet.IsEmpty()) {
      NSLog(@"[TS:%lld] No pose landmarks", packet.Timestamp().Value());
      return;
    }
    const auto& landmarks = packet.Get<::mediapipe::NormalizedLandmarkList>();
//    NSLog(@"[TS:%lld] Number of pose landmarks: %d", packet.Timestamp().Value(),
//          landmarks.landmark_size());
//    for (int i = 0; i < landmarks.landmark_size(); ++i) {
//      NSLog(@"\tLandmark[%d]: (%f, %f, %f, %f) %zu %zu", i, landmarks.landmark(i).x(),
//            landmarks.landmark(i).y(), landmarks.landmark(i).z(), landmarks.landmark(i).visibility(), self.imageBufferWidth, self.imageBufferHeight);
//    }
//      NSLog(@"[TS:%lld] angle12to14: %f", packet.Timestamp().Value(), [self getAngleOfLM:landmarks inA:12 inB:14]);
//      NSLog(@"[TS:%lld] angle12to14: %@", packet.Timestamp().Value(), [self getCurPMS:landmarks]);
      NSMutableDictionary *result =  [self checkPMS:landmarks];
      double totalDelta = [result[@"totalDelta"] doubleValue];
      int poseIdx = [result[@"poseIdx"] intValue];
      NSLog(@"[TS:%lld] result: %@", packet.Timestamp().Value(), result);
      if (poseIdx != -1) {
          long score = lround(1000000.0*(maxAngle-(totalDelta/matchPmsKeys.count/toleranceCoefficient))/maxAngle);
          textInfo = [NSString stringWithFormat:@"matched pose: %d score: %f ts: %lld", (poseIdx+1), (score/10000.0), packet.Timestamp().Value()];
//          tView.post(new Runnable() {
//              @Override
//              public void run() {
//                  tView.setText(textInfo);
//              }
//          });
      } else {
          textInfo = [NSString stringWithFormat:@"DM: %lld", packet.Timestamp().Value()];
//          tView.post(new Runnable() {
//              @Override
//              public void run() {
//                  tView.setText(textInfo);
//              }
//          });
      }
  }
}

- (NSMutableDictionary *)checkPMS:(const mediapipe::NormalizedLandmarkList&)curLandmarks {
//    Map<String, Number> result = new HashMap<>();
    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:2];

    NSMutableDictionary *curPms = [self getCurPMS:curLandmarks];
//    NSLog(@"curPms: %@", curPms);

    int idx = 1;
    NSMutableDictionary *logPms = [jsonPoseDataList objectAtIndex:idx];
//        Log.i(TAG, "pose_" + String.valueOf(idx) + ": " + logPms.angles.get(matchPmsKeys[0])
//                + ", " + logPms.angles.get(matchPmsKeys[1])
//                + ", " + logPms.angles.get(matchPmsKeys[2])
//                + ", " + logPms.angles.get(matchPmsKeys[3]));
//        Log.i(TAG, "curPms: " + curPms.angles.get(matchPmsKeys[0])
//                + ", " + curPms.angles.get(matchPmsKeys[1])
//                + ", " + curPms.angles.get(matchPmsKeys[2])
//                + ", " + curPms.angles.get(matchPmsKeys[3]));
    int matchedPoseIdx = -1;
    double total = 0;
    double rotateTotal = 0;
    double rotateOffset = 0;
    for (int poseIdx=0; poseIdx < jsonPoseDataList.count; poseIdx++) {
        NSUInteger cntMatchPmsKeys = matchPmsKeys.count;
        rotateTotal = 0;
        rotateOffset = 0;
        for (int i=0; i< cntMatchPmsKeys; i++) {
          //  id pmsKey = [matchPmsKeys objectAtIndex:i];
          NSString *pmsKey = (NSString *)[matchPmsKeys objectAtIndex:i];
          
          double curValue = [curPms[@"angles"][pmsKey] doubleValue];
          double poseValue = [[jsonPoseDataList objectAtIndex:poseIdx][@"angles"][pmsKey] doubleValue];

          if ((curValue*poseValue)<0 && (fabs(poseValue)>65)) {
              if (curValue < 0) {
                  rotateTotal += (180 + curValue) - poseValue;
              }
              else {
                  rotateTotal += curValue - (180 + poseValue);
              }
          }
          else {
              rotateTotal += curValue - poseValue;
          }

        }
        rotateOffset = rotateTotal / cntMatchPmsKeys; // matchPmsKeys.count;
        for (int i=0; i< cntMatchPmsKeys; i++) {
    //        id pmsKey = [matchPmsKeys objectAtIndex:i];
            NSString *pmsKey = (NSString *)[matchPmsKeys objectAtIndex:i];
            // ("11-13","12-14","13-15","14-16","23-25","24-26","25-27","26-28")
            double curValue = [curPms[@"angles"][pmsKey] doubleValue];
            double poseValue = [[jsonPoseDataList objectAtIndex:poseIdx][@"angles"][pmsKey] doubleValue];
            double tmpDlt = fabs((curValue - rotateOffset) - poseValue);
//            NSLog(@"%d %@ tmpDlt: %f", i, pmsKey, tmpDlt);
            if (tmpDlt < maxAngle) {
                total += tmpDlt;
            }
            else if ((curValue*poseValue)<0 && (fabs(poseValue)>65)) {
                tmpDlt = 180 - fabs(curValue - rotateOffset) - fabs(poseValue); // donot need calculate this every time
                if (tmpDlt < maxAngle) {
                    total += tmpDlt;
                }
                else {
                    total = -1;
                    break;
                }
            }
            else{
                total = -1;
                break;
            }

        }
        if (total > 0) {
            matchedPoseIdx = poseIdx;
            break;
        }
    }
    [result setValue:[NSNumber numberWithInt:matchedPoseIdx] forKey:@"poseIdx"];
    [result setValue:[NSNumber numberWithDouble:total] forKey:@"totalDelta"];
    [result setValue:[NSNumber numberWithDouble:rotateOffset] forKey:@"rotateOffset"];
//    result.put("totalDelta", total);
    return result;
}


- (NSMutableDictionary*)getCurPMS:(const mediapipe::NormalizedLandmarkList&)curLandmarks {
    NSMutableDictionary *mdictCurPMS = [NSMutableDictionary dictionaryWithCapacity:4];
    NSMutableDictionary *mdictAngles = [NSMutableDictionary dictionaryWithCapacity:16];
    
    NSUInteger cntMatchPmsKeys = matchPmsKeys.count;
    for (int i=0; i< cntMatchPmsKeys; i++) {
//        id pmsKey = [matchPmsKeys objectAtIndex:i];
        NSString *pmsKey = (NSString *)[matchPmsKeys objectAtIndex:i];
        NSArray *inputs = [[pmsKey stringByReplacingOccurrencesOfString:@"angle" withString:@""] componentsSeparatedByString:@"to"];
//        String[] inputs = pmsKey.replace("angle", "").split("to");
        if (inputs.count < 2) {
//            curPms.angles.put(pmsKey, 0d);
//            [mdictAngles setObject:pmsKey forKey:pmsKey];
            [mdictAngles setValue:[NSNumber numberWithDouble:0] forKey:pmsKey];
        } else {
            NSInteger inA = [[inputs objectAtIndex:0] integerValue];
            NSInteger inB = [[inputs objectAtIndex:1] integerValue];
//            curPms.angles.put(pmsKey, getAngleOfLM(curLandmarks, inA, inB));
            [mdictAngles setValue:[NSNumber numberWithDouble:[self getAngleOfLM:curLandmarks inA:(int)inA inB:(int)inB]] forKey:pmsKey];
        }
    }

    [mdictCurPMS setObject:mdictAngles forKey:@"angles"];
    return mdictCurPMS;
}



- (double)getAngleOfLM:(const mediapipe::NormalizedLandmarkList&)curLandmarks
            inA:(int) inA
            inB:(int) inB {
    float dltX = curLandmarks.landmark(inB).x() - curLandmarks.landmark(inA).x();
    float dltY = curLandmarks.landmark(inB).y() - curLandmarks.landmark(inA).y();
    if (dltX == 0) {
        if (dltY >= 0.0f) {
            return 90.0;
        }else {
            return -90.0;
        }
    }
//        return
//    return atan(-1.732)*180/M_PI;
    return atan(dltY*[self imageBufferHeight]/(dltX*[self imageBufferWidth]))*180/M_PI;
}


//+ (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
//{
//    if (jsonString == nil) {
//        return nil;
//    }
//    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
//    NSError *err;
//    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&err];
//    if (err) {
//        NSLog(@"json解析失败：%@",err);
//        return nil;
//    }
//    return dic;
//}

//+ (NSMutableArray *)loadLocalData {
//    // josn文件的路径
//    NSString *path = [[NSBundle mainBundle] pathForResource:@"home_timeline" ofType:@"json"];
//    // 将文件数据化
//    NSError * error=nil;
//    NSString *jsonString = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
//    //josn字符串转字典
//    NSDictionary *dic = [self dictionaryWithJsonString:jsonString];
//    //字典转模型
//    NSArray *data = [dic objectForKey:@"statuses"];
//    NSMutableArray *marray = [[NSMutableArray alloc]initWithCapacity:100];
//    for(id obj in data) {//obj是字典
//        id usermessage = [obj objectForKey:@"user"];
//        DWUser *user = [DWUser DWUserWithDictionary:usermessage];
//        DWStatus *status = [DWStatus DWStatusWithDictionary:obj andUserModel:user];
//        DWStatusFrame *statusFrame = [[DWStatusFrame alloc]init];
//        statusFrame.status = status;
//        [marray addObject:statusFrame];
//    }
//    return marray;
//}

//- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
//{
//    // Append the new data to receivedData.
//    // receivedData is an instance variable declared elsewhere.
//
//    [responseData appendData:data];
//}
//
//
//- (void)connectionDidFinishLoading:(NSURLConnection *)connection
//{
//NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
//NSError *e = nil;
//NSData *jsonData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
//NSDictionary *JSON = [NSJSONSerialization JSONObjectWithData:jsonData options: NSJSONReadingMutableContainers error: &e];
//
//}




@end
