$manifest = @{
    Path              = '.\prtgscript\prtgscript.psd1'
    RootModule        = 'prtgscript.psm1' 
    Author            = 'Gert-Jan Hiddink'
}
New-ModuleManifest @manifest