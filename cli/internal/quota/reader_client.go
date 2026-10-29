// SPDX-License-Identifier: MIT
package quota

import "github.com/modelplan/modelplan/cli/internal/readers"

// accountReadClient is the client-construction seam for synthetic protocol
// fixtures. Production always installs a fresh guard once per logical read;
// credential parsers and individual HTTP helpers must not reset its budget.
var accountReadClient = readers.NewReadClient
