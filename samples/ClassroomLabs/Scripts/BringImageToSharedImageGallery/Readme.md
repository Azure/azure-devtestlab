# Introduction
This script is used to bring a custom image from an Azure virtual machine (VM) to shared image gallery.

## Prerequisites
- Ensure that you have the [Azure PowerShell module](https://docs.microsoft.com/en-us/powershell/azure) installed.

# Directions
1. Open a PowerShell window.
2. Run `BringImageToSharedImageGallery.ps1`.  You can either pass all the required parameters when you run the script.  Or, you can run the script without the parameters so that you are prompted as shown in the next bullet.
3. When prompted, enter information about where the source VM resides and the shared image gallery where the custom image will be created.  Here are some helpful tips:

    - After you provide your subscription, you will be prompted with the following question: **Is this a DTL VM?**.  Assuming that you used an Azure VM to set up your image, you should answer **No** for this question.

    - The script will ask you to choose the **Image Definition in Shared Image Gallery** that will be used to create the custom image.   You can either choose an existing image definition or you can choose to create a new one.  To create a new image definition, you should choose the option **Create a new resource...**.

    - When you create a new image definition, you will be prompted for the following information:
        - Name of the image definition.
        - Whether the image is [specialized or generalized](https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries#generalized-and-specialized-images).
        - Publisher.  For more information about the value to enter, see [Image definitions](https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries#image-definitions).
        - Offer.  For more information about the value to enter, see [Image definitions](https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries#image-definitions).  
        - HyperVGeneration.  You should enter **v1**.

        The script will automatically create an an [image version](https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries#image-versions) of 1.0.0.

    - If you select an existing image definition, the script will automatically create an image version that has the PatchVersion incremented.  For example, if the previous image version is 1.0.0, the new version is 1.0.1.

For related information, refer to the following articles:
- [Bring a custom image to Shared Image Gallery](https://docs.microsoft.com/azure/lab-services/upload-custom-image-shared-image-gallery)
- [Shared Image Gallery overview](https://docs.microsoft.com/azure/virtual-machines/shared-image-galleries)
- [Attach or detach a Shared Image Gallery](https://docs.microsoft.com/azure/lab-services/how-to-attach-detach-shared-image-gallery)
- [Use a Shared Image Gallery](https://docs.microsoft.com/azure/lab-services/how-to-use-shared-image-gallery)