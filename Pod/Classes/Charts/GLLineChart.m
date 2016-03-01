#import "GLLineChart.h"
#import "GLChartData.h"
#import "UIColor+Helper.h"
#import "GLChartIndicator.h"

@interface GLLineChart ()

@property (nonatomic, strong) UIView           *maskLView;
@property (nonatomic, strong) UIView           *maskRView;
@property (nonatomic, strong) GLChartIndicator *indicator;

@end

@implementation GLLineChart

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    
    if (self) {
        [self addSubview:self.maskLView];
        [self addSubview:self.maskRView];
        [self addSubview:self.indicator];
    }
    
    return self;
}

#pragma mark - private methods

- (void)parseData {
    [super parseData];
    
    for (NSDictionary *dict in self.chartData.yValues) {
        NSArray *value = dict[@"value"];
        UIColor *color = [UIColor colorWithHexString:dict[@"color"]];
        
        if (value == nil || color == nil) {
            continue;
        }
        
        if (self.chartData.count == 0) {
            self.chartData.count = value.count;
        }
        
        for (NSNumber *item in value) {
            if (self.chartData.min > item.floatValue) {
                self.chartData.min = item.floatValue;
            }
            
            if (self.chartData.max < item.floatValue) {
                self.chartData.max = item.floatValue;
            }
        }
    }
}

- (void)initChart {
    [super initChart];
    
    CGFloat w = self.frame.size.width;
    CGFloat h = self.frame.size.height;
    
    CGFloat margin = self.chartData.margin;
    
    CGRect  containerFrame = {{0.0f,     margin},   {w,              h - margin}};
    CGRect  maskLViewFrame = {{0.0f,       0.0f},   {margin,         h - margin}};
    CGRect  maskRViewFrame = {{w - margin, 0.0f},   {margin,         h - margin}};
    CGRect  indicatorFrame = {{margin,     margin}, {w - margin * 2, h - margin * 2}};
    
    self.maskLView.frame        = maskLViewFrame;
    self.maskRView.frame        = maskRViewFrame;
    self.indicator.frame        = indicatorFrame;
    self.container.frame        = containerFrame;
    self.container.contentInset = UIEdgeInsetsMake(0.0f, margin, 0.0f, margin);
    
    if (self.chartData.isEnabledIndicator == NO &&
        self.chartData.visibleRangeMaxNum != 0  &&
        self.chartData.visibleRangeMaxNum < self.chartData.xValues.count) {
        CGFloat scale = (CGFloat)self.chartData.xValues.count / (CGFloat)self.chartData.visibleRangeMaxNum;
        CGRect  frame = {{0.0f, 0.0f}, {(w - margin * 2) * scale, h - margin * 2}};
        
        self.chartView.frame       = frame;
        self.container.contentSize = frame.size;
        
        if (self.chartData.chartInitDirection == GLChartInitDirectionLeft) {
            self.container.contentOffset = CGPointMake(-margin, 0.0f);
        } else {
            self.container.contentOffset = CGPointMake(frame.size.width - (w - margin), 0.0f);
        }
    } else {
        CGRect frame = {{0.0f, 0.0f}, {w - margin * 2, h - margin * 2}};
        
        self.chartView.frame       = frame;
        self.container.contentSize = frame.size;
    }
    
    self.chartView.layer.sublayers = nil;
}

- (void)drawChart {
    [super drawChart];
    
    self.chartData.scale = self.chartView.frame.size.height / self.chartData.max;
    
    for (NSDictionary *dict in self.chartData.yValues) {
        NSArray *value = dict[@"value"];
        UIColor *color = [UIColor colorWithHexString:dict[@"color"]];
        
        if (value == nil || color == nil) {
            continue;
        }
        
        CAShapeLayer *pathLayer = [[CAShapeLayer alloc] init];
        UIBezierPath *pathFrom  = [self getPathWithValue:value scale:0.0f                 close:NO];
        UIBezierPath *pathTo    = [self getPathWithValue:value scale:self.chartData.scale close:NO];
        
        pathLayer.path        = pathTo.CGPath;
        pathLayer.fillColor   = nil;
        pathLayer.lineWidth   = self.chartData.lineWidth;
        pathLayer.strokeColor = color.CGColor;
        
        [self.chartView.layer addSublayer:pathLayer];
        
        if (self.chartData.isFill) {
            CAShapeLayer *fillLayer = [[CAShapeLayer alloc] init];
            UIBezierPath *fillFrom  = [self getPathWithValue:value scale:0.0f                 close:YES];
            UIBezierPath *fillTo    = [self getPathWithValue:value scale:self.chartData.scale close:YES];
            
            fillLayer.path        = fillTo.CGPath;
            fillLayer.fillColor   = [color colorWithAlphaComponent:0.25f].CGColor;
            fillLayer.lineWidth   = 0.0f;
            fillLayer.strokeColor = color.CGColor;
            
            [self.chartView.layer addSublayer:fillLayer];
            
            if (self.chartData.animated) {
                [pathLayer addAnimation:[self fillAnimationWithFromValue:(__bridge id)(pathFrom.CGPath) toValue:(__bridge id)(pathTo.CGPath)]
                                 forKey:@"path"];
                [fillLayer addAnimation:[self fillAnimationWithFromValue:(__bridge id)(fillFrom.CGPath) toValue:(__bridge id)(fillTo.CGPath)]
                                 forKey:@"path"];
            }
        } else {
            if (self.chartData.animated) {
                [pathLayer addAnimation:[self pathAnimationWithFromValue:@0 toValue:@1]
                                 forKey:@"path"];
            }
        }
    }
}

- (void)loadComponents {
    [super loadComponents];
    
    if (self.chartData.isEnabledIndicator) {
        self.indicator.hidden    = NO;
        self.indicator.chartData = self.chartData;
    } else {
        self.indicator.hidden = YES;
    }
}

- (CGPoint)getPointWithValue:(NSArray *)value index:(NSUInteger)index scale:(CGFloat)scale {
    CGFloat w = self.chartView.frame.size.width;
    CGFloat h = self.chartView.frame.size.height;
    CGFloat x = w / (value.count - 1) * index;
    CGFloat y = h - scale * [value[index] floatValue];
    
    return CGPointMake(x, y);
}

- (UIBezierPath *)getPathWithValue:(NSArray *)value scale:(CGFloat)scale close:(BOOL)close {
    UIBezierPath *path = [[UIBezierPath alloc] init];
    
    for (int i = 0; i < value.count; i++) {
        CGPoint point = [self getPointWithValue:value index:i scale:scale];
        
        if (i == 0) {
            [path moveToPoint:point];
        } else {
            [path addLineToPoint:point];
        }
    }
    
    if (close) {
        [path addLineToPoint:[self getPointWithValue:value index:value.count - 1 scale:0.0f]];
        [path addLineToPoint:[self getPointWithValue:value index:0 scale:0.0f]];
        [path addLineToPoint:[self getPointWithValue:value index:0 scale:scale]];
    }
    
    return path;
}

- (CABasicAnimation *)fillAnimationWithFromValue:(id)fromValue toValue:(id)toValue {
    CABasicAnimation *fillAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    
    fillAnimation.duration       = self.chartData.duration;
    fillAnimation.fromValue      = fromValue;
    fillAnimation.toValue        = toValue;
    fillAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    return fillAnimation;
}

- (CABasicAnimation *)pathAnimationWithFromValue:(id)fromValue toValue:(id)toValue {
    CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"strokeEnd"];
    
    pathAnimation.duration       = self.chartData.duration;
    pathAnimation.fromValue      = fromValue;
    pathAnimation.toValue        = toValue;
    pathAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    
    return pathAnimation;
}

#pragma mark - getters and setters

- (UIView *)maskLView {
    if (_maskLView == nil) {
        _maskLView = [[UIView alloc] init];
        
        _maskLView.backgroundColor = [UIColor whiteColor];
    }
    
    return _maskLView;
}

- (UIView *)maskRView {
    if (_maskRView == nil) {
        _maskRView = [[UIView alloc] init];
        
        _maskRView.backgroundColor = [UIColor whiteColor];
    }
    
    return _maskRView;
}

- (GLChartIndicator *)indicator {
    if (_indicator == nil) {
        _indicator = [[GLChartIndicator alloc] init];
    }
    
    return _indicator;
}

@end
