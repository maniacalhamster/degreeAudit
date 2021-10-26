# Using all paths relative to root of the git repository
$root   = git rev-parse --show-toplevel;

# Parse the HTML of the audit
$html   = New-Object -ComObject 'HTMLFile';
$html.write([ref]'');
$html.write([System.Text.Encoding]::Unicode.GetBytes($(Get-Content "$root/audit.html")));

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
} | Format-Table -Property Term, Grade, Class, Credits -GroupBy Term;

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

    $neededCourses += $([pscustomobject]@{
        'title'     = $title;
        'count'     = $count;
        'notFrom'   = $notFrom;
        'courses'   = $courses;
    });
}

@{
    'Taken'     = $formatted;
    'Needed'    = $neededCourses | Format-Table -Property count, title, courses, notFrom -Wrap;
}