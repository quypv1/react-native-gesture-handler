#import "REANode.h"

#import <React/RCTDefines.h>

static NSUInteger loopID = 1;

@interface REANode ()

@property (nonatomic) NSUInteger lastLoopID;
@property (nonatomic) id memoizedValue;
@property (nonatomic, copy, readonly) NSMapTable<REANodeID, REANode *> *childNodes;

@end

@implementation REANode

- (instancetype)initWithID:(REANodeID)nodeID config:(NSDictionary<NSString *,id> *)config
{
    if ((self = [super init])) {
      _nodeID = nodeID;
      _lastLoopID = 0;
    }
    return self;
}

RCT_NOT_IMPLEMENTED(- (instancetype)init)

- (id)evaluate
{
  return 0;
}

- (id)value
{
  if (_lastLoopID < loopID) {
    _lastLoopID = loopID;
    return (_memoizedValue = [self evaluate]);
  }
  return _memoizedValue;
}

- (void)addChild:(REANode *)child
{
  if (!_childNodes) {
    _childNodes = [NSMapTable strongToWeakObjectsMapTable];
  }
  if (child) {
    [_childNodes setObject:child forKey:child.nodeID];
    child.lastLoopID = 0;
  }
}

- (void)removeChild:(REANode *)child
{
  if (!_childNodes) {
    return;
  }
  if (child) {
    [_childNodes removeObjectForKey:child.nodeID];
  }
}

- (void)markUpdated
{
  [[REANode updatedNodes] addObject:self];
}

+ (NSMutableArray<REANode *> *)updatedNodes
{
  static NSMutableArray<REANode *> *updatedNodes;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    updatedNodes = [NSMutableArray new];
  });
  return updatedNodes;
}

+ (void)runPropUpdates
{
  NSMutableSet<REANode *> *visitedNodes = [NSMutableSet new];
  __block __weak void (^ weak_FindAndUpdateNodes)(REANode *);
  void (^findAndUpdateNodes)(REANode *);
  weak_FindAndUpdateNodes = findAndUpdateNodes = ^(REANode *node) {
    if ([visitedNodes containsObject:node]) {
      return;
    } else {
      [visitedNodes addObject:node];
    }
    if ([node respondsToSelector:@selector(update)]) {
      [(id)node update];
    } else {
      for (REANode *child in [node childNodes]) {
        weak_FindAndUpdateNodes(child);
      }
    }
  };
  for (NSUInteger i = 0; i < [self updatedNodes].count; i++) {
    findAndUpdateNodes([[self updatedNodes] objectAtIndex:i]);
  }
  [[self updatedNodes] removeAllObjects];
  loopID++;
}

@end
