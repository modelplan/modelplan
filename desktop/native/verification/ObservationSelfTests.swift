// SPDX-License-Identifier: MIT
#if MODELPLAN_OBSERVATION_SELF_TEST
@main struct ObservationSelfTests {
    static func main() {
        var proof=RAFProgress()
        precondition(proof.observe(frame:1,now:100)=="not-run")
        precondition(proof.observe(frame:2,now:101.999)=="not-run")
        precondition(proof.observe(frame:3,now:102)=="pass")
        var stationary=RAFProgress()
        _=stationary.observe(frame:1,now:0)
        precondition(stationary.observe(frame:1,now:3)=="fail")
        precondition(stationary.observe(frame:2,now:4) != "pass")
        let observation=WindowObservation(appActive:false,keyWindow:true,windowVisible:true,occlusionVisible:true)
        precondition(!observation.ready)
        precondition(observation.fields["appActive"] as? Bool == false)
        print("Observation pure-state checks pass; no NSApplication, GUI or PID probe")
    }
}
#endif
