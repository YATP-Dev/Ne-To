import Testing
@testable import NeTo

@Test func exclusionsMatchOnlyTheChosenBundleIdentifier() {
    let excluded = [ExcludedApplication(bundleID: "com.example.editor", name: "Editor")]
    #expect(ApplicationExclusions.contains(bundleID: "com.example.editor", in: excluded))
    #expect(!ApplicationExclusions.contains(bundleID: "com.example.editor.helper", in: excluded))
    #expect(!ApplicationExclusions.contains(bundleID: "com.example.other", in: excluded))
    #expect(!ApplicationExclusions.contains(bundleID: nil, in: excluded))
}
