package example

default allow = false

Type() = "my_example"

Input() = {
    "my_flag": input.my_flag
}

# list of evidence and required for verification.
# Map between the name of evidence you are requiring, 
# select what labels in the context you expect the evidence to have.
List(ctx) = {
    "some_evidence": [ctx]
}

# allow: (boolean) Indicates whether the verification succeeded or failed
# valuations: (array) An array of valuations, each of which contains a result indicating whether the corresponding rule succeeded or failed
Verify = result {
    
    result := {
        "allow": allow,
        "subject": some_evidence_subject,
        "valuations": valuation,
    }

}

allow = result {
    config := input.config
    verifierContext := input.context
    evidence := input.evidence.some_evidence[0]

    print("Config: ", config)
    print("Verifier-context: ", verifierContext)
    # print("Evidence: ", evidence.)

    myFlagEnabled(config.my_flag)
    result := true
}

valuation[{"results": [{"message": "user disabled - my_regulation"}]}] {
    config := input.config
    not myFlagEnabled(config.my_flag)
}

valuation[{"results": [{"message": "some_evidence evidence missing"}]}] {
    config := input.config
    myFlagEnabled(config.my_flag)

    not input.evidence.some_evidence
}

valuation[{"results": [{"message": sprintf("missing evidence %d", [count(evidenceL)])}]}] {
    config := input.config
    myFlagEnabled(config.my_flag)

    evidenceL := input.evidence.some_evidence
    count(evidenceL) == 0
}

valuation[{"results": [{"message": "missing subject some_evidence"}]}] {
    config := input.config
    myFlagEnabled(config.my_flag)

    evidenceL := input.evidence.some_evidence
    count(evidenceL) > 0

    not evidenceL[0].subject
}


some_evidence_subject = result {
    config := input.config

    not myFlagEnabled(config.my_flag)
    result = []
}
some_evidence_subject = result {
    config := input.config
    myFlagEnabled(config.my_flag)

    evidence := input.evidence.some_evidence[0]
    result = evidence_subject(evidence)
}


evidence_subject(evidence) = subject {
    subject = evidence.subject
}

myFlagEnabled(my_flag) {
    my_flag == "true"
}