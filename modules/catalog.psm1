# Using all paths relative to root of the git repository
$root   = git rev-parse --show-toplevel;

# Import network module to make GET requests
Import-Module "$root/modules/network.psm1";

# Download courselists as needed, mapping to departments for quicker access later
$departmentList = @{};

# Helper function to get the ID + Name + Description + Requirement combos
#  - Search for course-name element for ID and title
#  - Sibling contains description and requirement
# Add the set of all the courses under the department to the departmentlist mapping if needed
# Finally return the list of courses under the department
function Get-DepartmentCourses($department) {
    if (-not ($departmentList.Keys -contains $department)) {

        $source_url = "https://catalog.ucsd.edu/courses/{0}.html" -f $department;
        $raw_data = New-Object -ComObject 'HTMLFile';
        $raw_data.Write([ref]'');
        $raw_data.Write([System.Text.Encoding]::Unicode.GetBytes($(Invoke-GetRequest $source_url).Content));

        $courses = @{};

        $raw_data.GetElementsByClassName('course-name') | ForEach-Object {
            $name = $_.innerText -split '\. ';
            $desc = $_.nextSibling().innerText -split 'Prerequisites: ';
            $courses.Add($name[0], [PSCustomObject]@{
                    id     = $name[0];
                    name   = $name[1];
                    desc   = $desc[0];
                    prereq = $desc[1];
                });
        }

        $departmentList.Add($department, $courses);
    }

    return $departmentList.$department;
}

# Format input into a "DEPT ###" form
#  - check for division between letters and numbers and force a space
#  - ensure the department code is all uppercase
# Format resulting course info into a list and return
function Get-CourseInfo($courseID) {
    $courseID   = ($courseID -split '(?<=[A-Z])\s?(?=\d)');
    $department = $courseID[0].ToUpper();
    $courseID   = $department + " " + $courseID[1];

    return (Get-DepartmentCourses $department).$courseID | Format-List;
}

Export-ModuleMember -Function Get-CourseInfo;
Export-ModuleMember -Function Get-DepartmentCourses;