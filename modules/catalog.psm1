# Using all paths relative to root of the git repository
$root   = git rev-parse --show-toplevel;

Import-Module "$root/modules/network.psm1";

$departmentList = @{};
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

function Get-CourseInfo($courseID) {
    $department = ($courseID -split ' ')[0];

    return (Get-DepartmentCourses $department).$courseID | Format-List;
}

Export-ModuleMember -Function Get-CourseInfo;
Export-ModuleMember -Function Get-DepartmentCourses;