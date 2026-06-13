// Tests the timed-match clock added for Point Rush (M2-021): counting,
// expiry, and the timer-expiry semantics (rally plays out; leader wins; a tie
// goes to a golden point). Pure engine — no Flame.
import 'package:flutter_test/flutter_test.dart';
import 'package:smash_bros/engine/constants.dart';
import 'package:smash_bros/engine/entities/court.dart';
import 'package:smash_bros/engine/rules/match_fsm.dart';
import 'package:smash_bros/engine/rules/match_phase.dart';

void main() {
  group('untimed match (Classic)', () {
    test('never expires and reports no remaining time', () {
      final fsm = MatchFsm()..startMatch(0);
      for (var i = 0; i < 1000; i++) {
        fsm.tickMatchClock(i);
      }
      expect(fsm.isTimed, isFalse);
      expect(fsm.timeExpired, isFalse);
      expect(fsm.remainingTicks, 0);
      expect(fsm.phase, MatchPhase.servePending); // not ended by a clock
    });
  });

  group('timed match clock', () {
    test('counts up, reports remaining, and expires at the limit', () {
      final fsm = MatchFsm(timeLimitTicks: 5)..startMatch(0);
      expect(fsm.isTimed, isTrue);
      expect(fsm.remainingTicks, 5);
      for (var i = 0; i < 5; i++) {
        fsm.tickMatchClock(i);
      }
      expect(fsm.matchClockTicks, 5);
      expect(fsm.timeExpired, isTrue);
      expect(fsm.remainingTicks, 0);
    });

    test('does NOT tick in preMatch or matchOver', () {
      // tickMatchClock is a no-op in preMatch.
      final fsm = MatchFsm(timeLimitTicks: 5)..tickMatchClock(0);
      expect(fsm.matchClockTicks, 0);
      fsm
        ..startMatch(1)
        ..abortMatch(2, 'test'); // → matchOver
      final atOver = fsm.matchClockTicks;
      fsm.tickMatchClock(3);
      expect(fsm.matchClockTicks, atOver);
    });
  });

  group('expiry between rallies (servePending)', () {
    test('ends the match when a leader is decided', () {
      final fsm = MatchFsm(timeLimitTicks: 3)..startMatch(0);
      fsm.scoreboard.leftScore = 2; // left leads
      for (var i = 0; i < 3; i++) {
        fsm.tickMatchClock(i);
      }
      expect(fsm.phase, MatchPhase.matchOver);
    });

    test('a tie keeps play going (golden point)', () {
      final fsm = MatchFsm(timeLimitTicks: 3)..startMatch(0);
      // 0-0 tie at expiry.
      for (var i = 0; i < 3; i++) {
        fsm.tickMatchClock(i);
      }
      expect(fsm.timeExpired, isTrue);
      expect(fsm.phase, MatchPhase.servePending); // still playing
    });
  });

  group('expiry at a point boundary (rally played out)', () {
    /// Drives the FSM to a just-scored state for [winnerScore]-[loserScore]
    /// with the clock already expired, then completes the point pause.
    MatchFsm scoredAtExpiry({
      required int leftScore,
      required int rightScore,
      required CourtSide pointWinner,
    }) {
      final fsm = MatchFsm(timeLimitTicks: 2)
        ..startMatch(0)
        ..onServeTossed(1) // → inPlay
        ..tickMatchClock(2)
        ..tickMatchClock(3); // clock now expired (still inPlay → no end yet)
      expect(fsm.timeExpired, isTrue);
      // Stand in for "a point just landed": enter pointScored with the result.
      fsm
        ..phase = MatchPhase.pointScored
        ..pointWinner = pointWinner
        ..pointPauseTicks = kPointPauseTicks - 1;
      fsm.scoreboard
        ..leftScore = leftScore
        ..rightScore = rightScore;
      fsm.tickPointPause(10); // completes the pause → end-of-point decision
      return fsm;
    }

    test('leader at expiry wins when the rally finishes', () {
      final fsm = scoredAtExpiry(
        leftScore: 3,
        rightScore: 1,
        pointWinner: CourtSide.left,
      );
      expect(fsm.phase, MatchPhase.matchOver);
    });

    test('a tie-levelling point at expiry goes to a golden point', () {
      // The point evened the score (2-2) — still tied at expiry → keep playing.
      final fsm = scoredAtExpiry(
        leftScore: 2,
        rightScore: 2,
        pointWinner: CourtSide.left,
      );
      expect(fsm.phase, MatchPhase.servePending);
    });
  });

  group('determinism', () {
    test('the match clock is included in the copy', () {
      final fsm = MatchFsm(timeLimitTicks: 100)..startMatch(0);
      for (var i = 0; i < 7; i++) {
        fsm.tickMatchClock(i);
      }
      final clone = fsm.copy();
      expect(clone.matchClockTicks, fsm.matchClockTicks);
      expect(clone.timeLimitTicks, fsm.timeLimitTicks);
      expect(clone.remainingTicks, fsm.remainingTicks);
    });
  });
}
