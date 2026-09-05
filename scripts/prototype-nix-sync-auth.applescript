try
  set effectiveUser to do shell script "/usr/bin/id -u" with administrator privileges
  if effectiveUser is not "0" then error "Expected root, got UID " & effectiveUser
  return "authenticated: uid=0"
on error errorMessage number errorNumber
  if errorNumber is -128 then return "cancelled"
  error errorMessage number errorNumber
end try
