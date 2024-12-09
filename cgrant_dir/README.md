# CommunityGrants: Decentralized Community Project Funding Platform

CommunityGrants is a decentralized application (dApp) built on the Stacks blockchain that enables communities to fund and support local projects through milestone-based grants. This platform leverages smart contracts to ensure transparency, fairness, and community involvement in the grant-making process.

## Features

- **Project Submission**: Community members can submit project proposals with detailed information and funding requirements.
- **Milestone-based Funding**: Projects are funded in phases, ensuring accountability and progress-driven disbursement of funds.
- **Community Review System**: A decentralized review process allows community members to endorse or oppose projects.
- **Weighted Voting**: Reviews are weighted based on the reviewer's contribution, ensuring that those with more stake have a proportionally larger say.
- **Automated Approval Process**: Projects are automatically approved or rejected based on community consensus.
- **Phase Progress Tracking**: Project coordinators can submit progress reports for each phase, which are then reviewed and approved.

## Smart Contract Overview

The core of CommunityGrants is a Clarity smart contract that manages the entire process. Here's a brief overview of its main components:

- **Data Storage**: Uses maps to store information about Projects, Phases, and Reviews.
- **Project Submission**: Allows users to submit new project proposals.
- **Project Review**: Enables community members to review and contribute to projects.
- **Phase Management**: Handles the submission of phase progress reports and approval of completed phases.
- **Result Calculation**: Automatically calculates the approval status of projects based on community reviews.

## Getting Started

To interact with the CommunityGrants platform, you'll need to:

1. Set up a Stacks wallet (like Hiro Wallet).
2. Obtain some STX tokens for transactions.
3. Connect to the Stacks network where the contract is deployed.

## Key Functions

- `submit-project`: Submit a new project proposal.
- `review-project`: Review and contribute to a project.
- `submit-phase-progress`: Submit a progress report for a project phase.
- `approve-phase`: Approve a completed project phase (contract owner only).
- `get-project-result`: Check the approval status of a project.

## Contributing

We welcome contributions to the CommunityGrants project! Please read our contributing guidelines before submitting pull requests.

## Contact

For questions, suggestions, or support, please open an issue in the GitHub repository or contact the maintainers at [INSERT CONTACT INFORMATION].

---

Build a stronger community, one project at a time with CommunityGrants!