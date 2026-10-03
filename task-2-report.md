
## Round 2 Fix - Stem Fallback Test Update

**Date:** 2026-10-03

### Change Made
Updated the stem fallback test case in `test/quiz/quiz_generator_test.dart` to use a conjugated form where the dictionary form '가다' does NOT appear verbatim, so the fallback to 다-stripped stem '가' is actually exercised.

- Changed `exampleKo` from `'학교에 가다'` to `'학교에 가요'`
- '가요' contains the stem '가' verbatim (unlike '갑니다' where stem becomes '갑')
- This exercises the fallback code path that strips '다' from '가다' to get '가' and searches for it

### Test Results
All 13 tests in `test/quiz/quiz_generator_test.dart` pass.

