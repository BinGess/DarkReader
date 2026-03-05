//
//  DarkReaderTests.swift
//  DarkReaderTests
//
//  Created by ByteDance on 2026/3/3.
//

import Testing
@testable import DarkReader

struct DarkReaderTests {

    @Test func darkShieldPointsUsesDurationAndWeight() async throws {
        let points = SharedDataManager.darkShieldPoints(durationSeconds: 3600, reductionRatio: 0.38)
        #expect(points == 380)
    }

    @Test func darkShieldPointsClampsInvalidInputs() async throws {
        #expect(SharedDataManager.darkShieldPoints(durationSeconds: 0, reductionRatio: 0.5) == 0)
        #expect(SharedDataManager.darkShieldPoints(durationSeconds: 1800, reductionRatio: -0.2) == 0)
        #expect(SharedDataManager.darkShieldPoints(durationSeconds: 1800, reductionRatio: 1.2) == 500)
    }

}
