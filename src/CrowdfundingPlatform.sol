// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

contract CrowdfundingPlatform {
    address public platformAdmin;

    enum ProjectStatus {
        Active,
        Cancelled,
        Finished
    }

    struct Project {
        uint256 projectID;
        address projectOwner;
        string title;
        string description;
        uint256 fundingGoal;
        uint256 totalFunded;
        uint256 endTime;
        ProjectStatus status;
    }

    uint256 public feePercentage;
    Project[] public projects;
    bool private locked = false;
    mapping(uint256 => mapping(address => uint256)) public contributions;

    event ProjectCreated(uint256 indexed projectID, address creator);
    event FundReceived(
        uint256 indexed projectID,
        address sender,
        uint256 amount
    );
    event ProjectCancelled(uint256 indexed projectID);
    event FundWithdraw(
        uint256 indexed projectID,
        address sender,
        uint256 amount
    );
    event Refund(uint256 indexed projectID, address sender, uint256 amount);

    constructor() {
        platformAdmin = msg.sender;
        feePercentage = 5;
    }

    modifier onlyOwner() {
        require(msg.sender == platformAdmin, "Caller is not the owner");
        _;
    }

    modifier noReentrant() {
        require(!locked, "Reentrant call detected");
        locked = true;
        _;
        locked = false;
    }

    /**
     * @notice Create a new crowdfunding project by anyone
     * @param _title  project title
     * @param _description  description about the project
     * @param _fundingGoal total money need to be funded
     * @param _duration  crowdfunding duration
     * @return projectId  projectId
     */
    function createProject(
        string memory _title,
        string memory _description,
        uint256 _fundingGoal,
        uint256 _duration
    ) external returns (uint) {
        uint256 projectId = projects.length;
        Project storage newProject = projects.push();
        newProject.projectID = projectId;
        newProject.projectOwner = msg.sender;
        newProject.title = _title;
        newProject.description = _description;
        newProject.fundingGoal = _fundingGoal;
        newProject.totalFunded = 0;
        newProject.endTime = block.timestamp + _duration;
        newProject.status = ProjectStatus.Active;
        emit ProjectCreated(projectId, msg.sender);
        return projectId;
    }

    /**
     * @notice fund the project
     * @param _projectID ID of project
     */
    function fundProject(uint256 _projectID) external payable {
        Project storage project = projects[_projectID];
        // Check if the end time has not been reached and the funding goal is not met
        require(block.timestamp < project.endTime, "Funding period has ended");

        // Check if the project funding goal has been reached or exceeded
        require(
            project.totalFunded < project.fundingGoal,
            "Funding goal has been reached or exceeded"
        );
        require(
            project.status != ProjectStatus.Finished,
            "project was sucessed and finshed"
        );
        require(
            project.status != ProjectStatus.Cancelled,
            "project was cancelled by creator"
        );
        // Check if the sent amount is greater than zero
        require(msg.value > 0, "Funding amout must be greater than 0");
        contributions[_projectID][msg.sender] += msg.value;
        project.totalFunded += msg.value;
        emit FundReceived(_projectID, msg.sender, msg.value);
    }

    /**
     * @notice when reach the endtime but not get the fundingGoal or
     * project creator canel the project, user can call the refund to
     * get money back
     * @param _projectID ID of project
     */
    function refund(uint256 _projectID) external noReentrant {
        Project storage project = projects[_projectID];
        require(
            project.status != ProjectStatus.Finished,
            "Funding is Success and the project creator withraw the fund"
        );
        // If the project is still active but the end time has not been reached
        if (project.status == ProjectStatus.Active) {
            require(block.timestamp > project.endTime, "not reach the endTime");
            require(
                project.totalFunded < project.fundingGoal,
                "Funding had reached the goal"
            );
        }
        uint256 funderAmount = getContribution(_projectID);
        require(
            project.totalFunded >= funderAmount && funderAmount != 0,
            "not enough to refund!"
        );
        project.totalFunded -= funderAmount;
        contributions[_projectID][msg.sender] -= funderAmount;
        (bool success, ) = msg.sender.call{value: funderAmount}("");
        if (!success) {
            revert("refund failed!");
        }
        emit Refund(_projectID, msg.sender, funderAmount);
    }

    /**
     * @notice cancel the project fungding
     * @param _projectID ID of project
     */
    function cancalProject(uint256 _projectID) external {
        Project storage project = projects[_projectID];
        require(
            project.projectOwner == msg.sender,
            "Caller is not the project owner!"
        );
        project.status = ProjectStatus.Cancelled;
        emit ProjectCancelled(_projectID);
    }

    /**
     * @notice withdraw the project fungding
     * @param _projectID ID of project
     */
    function withdraw(uint256 _projectID) external noReentrant {
        Project storage project = projects[_projectID];
        require(
            project.projectOwner == msg.sender,
            "Caller is not the project owner!"
        );
        require(
            project.status == ProjectStatus.Active,
            "the project were finished or cancelled "
        );
        uint256 projectTotalFunded = project.totalFunded;
        require(
            projectTotalFunded >= project.fundingGoal,
            "crowfund not reach the goal"
        );
        uint256 paltformFee = (projectTotalFunded * feePercentage) / 100;
        project.totalFunded = 0;
        project.status = ProjectStatus.Finished;
        // Pay platform fee
        (bool success, ) = platformAdmin.call{value: paltformFee}("");
        if (!success) {
            revert("pay platform fee failed!");
        }
        // Transfer funds to project owner
        (success, ) = msg.sender.call{value: projectTotalFunded - paltformFee}(
            ""
        );
        if (!success) {
            revert("refund failed!");
        }
        emit FundWithdraw(
            _projectID,
            msg.sender,
            projectTotalFunded - paltformFee
        );
    }

    function getContribution(uint256 _projectID) public view returns (uint256) {
        return contributions[_projectID][msg.sender];
    }

    function setPlatformFee(uint256 _feePercentage) external onlyOwner {
        feePercentage = _feePercentage;
    }

    function transferOwnership(address _newAdmin) external onlyOwner {
        platformAdmin = _newAdmin;
    }

    function getProjectFundedAmout(
        uint256 _projectID
    ) external view returns (uint256) {
        Project memory project = projects[_projectID];
        return project.totalFunded;
    }

    function getProjectEndTime(
        uint256 _projectID
    ) external view returns (uint256) {
        Project memory project = projects[_projectID];
        return project.endTime;
    }

    function getProjectFundingGoal(
        uint256 _projectID
    ) external view returns (uint256) {
        Project memory project = projects[_projectID];
        return project.fundingGoal;
    }

    function getProjectStatus(
        uint256 _projectID
    ) external view returns (ProjectStatus) {
        Project memory project = projects[_projectID];
        return project.status;
    }

    function getProjectCount() public view returns (uint) {
        return projects.length;
    }

    fallback() external payable {}

    receive() external payable {}
}
