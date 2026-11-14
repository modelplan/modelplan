# U7 wired plan

1. Keep the generated credential DTO unchanged; fixed helper denies every request
   without token material until R2. No quota protocol, reader or caller anchor.
2. Prove byte identity from two clean roots on the hosted macOS runner. Publish one
   artifact pin bound to helper/Wire/compiler/SDK/recipe inputs.
3. Embed the same artifact in both app builds, without rebuilding/re-signing it.
   Check final bundle bytes against the independent pin. Synthetic fixtures do not
   count as production candidate or Keychain/A14 proof.
4. Under a fresh U6 lease, construct the helper CredentialAgent in the normal
   EngineStoreConnection and bind its weak authority to #365's isCurrent API.
5. Open the wired draft with R2 and outstanding integration/candidate gates stated.
   Real backend enablement waits for authenticated Developer ID XPC on both peers.

No Keychain, signing identity, trust, GUI or shared-disk action belongs to this batch.
