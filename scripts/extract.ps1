# Using all paths relative to root of the git repository
$root   = git rev-parse --show-toplevel;

Import-Module "$root/modules/catalog.psm1";

# Write a helper function to handle parsing the format of courses
#   returned by degreeAudit into the DEPT ID format used by catalog module
function Get-CourseIDs($courses) {
    # Store results in an array to return later
    $courseIDs  = @();

    # Split the block of courses into lines, filtering out empty lines,
    #     the beginning 'COURSES: ' section of each line, and any ORs (for notFrom blocks)
    # Trim any additional whitespace and Split results on spaces and commas to 
    #     seperate deptnames from IDs and 'TO' range markers
    $lines = $courses -split '$',0,'multiline' -replace 'OR' | Where-Object {$_ -ne ''};
    $lines -replace '.*: ' | ForEach-Object {
        $_.Trim() -split ' ' -split ',' | ForEach-Object {
            # Recognize a range and notify the rest of code to handle it
            if ($_ -eq 'TO') {
                $to     = $true;
                $from   = $courseIDs[-1];
            } 
            # Any other purely alphabetic strings indicates department code
            elseif ($_ -notmatch '\d') {
                $dept   = $_;
            } 
            # Finally, leaving only course IDs
            else {
                # Range detection 
                # - get rid of dept portion of $from
                # - reset range detection
                if ($to) {
                    $from   = ($from -split ' ')[1];
                    $to     = $false;
                    # Detecting an ###A-F range
                    # - extract the base
                    # - iterate from the character after last courseID
                    #      to character of current courseID
                    if ($from -match '[A-Z]') {
                        $base   = $from.Substring(0, $from.Length - 1);
                        @(([char]([int]$from[-1] + 1))..($_[-1])) | ForEach-Object {
                            $courseIDs += "$dept $($base+$_)";
                        }
                    }
                    # Detecting an ### - ### range
                    # - iterate from the last courseID
                    #      to current courseID
                    else {
                        @(([int]$from + 1)..$_) | ForEach-Object {
                            $courseIDs += "$dept $_";
                        }
                    }
                } 
                # No range indicates just keep adding that sole course IDs under the current dept
                else {
                    $courseIDs += "$dept $_";
                }
            }
        }
    }
    return $courseIDs;
}

# Check if the audit HTML has been downloaded, calling on runAudit if needed
if (-not (Test-Path "$root/data/audit.html")) {
    ."$root/scripts/runAudit.ps1";
}

# Parse the HTML of the audit
$html   = New-Object -ComObject 'HTMLFile';
$html.write([ref]'');
$html.write([System.Text.Encoding]::Unicode.GetBytes($(Get-Content "$root/data/audit.html")));

# 'takenCourse' classname used to grab info for taken course elements
# Iterate through each element
#  - generate a PSCustomObject with childNode data (header index based)
#  - store into an array after checking for duplicates
$takenCourses   = $html.GetElementsByClassName('takenCourse');
$headers    = ('Term', 'Class', 'Credits', 'Grade');
$rawData    = @();
$takenCourses | ForEach-Object {
    $course = $_;
    $entry  = @{};

    $headers | ForEach-Object {
        $nodeIndex  = $headers.indexOf($_);
        $entry.Add($_, $course.childNodes[$nodeIndex].innerText);
    }

    $entry  = [pscustomobject]$entry;

    if (-not $rawData.Length -or -not ($rawData.Class -contains $entry.Class)) {
        $rawData += $entry;
    }
}

# Format the raw data by sorting with respect to
# 1) Year
# 2) WI(nter) -> SP(ring) -> S(ummer) -> FA(ll)
#
# Then, format the results decide ordering of property:
# Term -> Grade -> Class -> Credits
#
# Finally, group by term for visual clarity
$formatted  = $rawData | Sort-Object {
    $_.Term.Substring(2);
    $(Switch -Regex ($_.Term) {
        'WI..' {1};
        'SP..' {2};
        'S[0-9]..' {3};
        'FA..' {4};
    })
};

# 'subreqNeeds' classname used to grab info for needed course elements
# Iterate through each element
#  - generate a PSCustomObject, looking in sibling elements for the data:
#    - title    : name of subrequirement need
#    - count    : number of courses under that title left
#    - notFrom  : courses that won't give credit for title
#    - course   : options / list of courses to take / choose from
#  - store into an array after collecting data
$neededCourses = @();
$html.GetElementsByClassName("subreqNeeds") | ForEach-Object {
    $parent     = $_.parentElement;
    $title      = $parent.GetElementsByClassName('subreqTitle')[0].innerText;
    $count      = $parent.GetElementsByClassName('count number')[0].innerText;
    $notFrom    = $parent.GetElementsByClassName('notcourses')[0].innerText;
    $courses    = $parent.GetElementsByClassName('selectfromcourses')[0].innerText;

    $notFrom    = Get-CourseIDs $notFrom;
    $courses    = Get-CourseIDs $courses | Where-Object {
        ($formatted.Class -notcontains $_) -and ($notFrom -notcontains $_)
    }

    $neededCourses += $([pscustomobject]@{
        'title'     = $title;
        'count'     = $count;
        'courses'   = $courses;
    });
}

@{
    'Taken'     = $formatted;
    'Needed'    = $neededCourses;
}